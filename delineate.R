###Inputs###
  #lc_map = A binary land cover raster, where suitable habitat = 1 and non-suitable habitat/matrix = 0
  #res_m = The resolution of the land cover raster in metres.
  #edge_depth = The desired edge effect distance in metres. This will be converted to units of cells within the function and some resolution may thus be lost.
  #gap_area = The maximum area (in m^2) of gaps (i.e., areas of non-suitable habitat encompassed by areas of suitable habitat) that should be filled. 
              #Gaps are always replaced at the end of processing so that non-suitable habitat cells are not misclassified in the output. 
              #Default is NA (i.e., no gaps will be filled). 
              #The area of gaps to be filled may be selected based on the taxon-specific minimum area of matrix habitat that results in edge effects within sorrounding habitat
  #corridor_width = The maximum width, in metres, of connecting habitat corridors that should be cut by the function. 
                    #This will be converted to units of cells within the function and some resolution may thus be lost.
             
             
###Outputs###
  #A list containing:
    #Landscape_Raster = A raster of equal extent as the input raster, where individual habitat fragments identified by the function are labelled with unique cell values.
    #Patch_Polygons = An sf data frame containing individual polygons for each fragment identified by the function. Fragment numberings match those in Landscape_Raster.


###Dependencies and Known Issues###

#This function depends on several packages.
#The major dependency is EBImage, produced by BioConductor (https://bioconductor.org/packages/release/bioc/html/EBImage.html)
#EBImage requires an installation of ImageMagik and fftw3, which can be troublesome to install. 
#Here are a couple of helpful blog posts: 
  #https://megapteraphile.wordpress.com/2019/09/29/challenges-installing-ebimage-in-r/
  #https://joelgranados.com/2012/04/05/very-painful-ebimage-install-on-windows/

#Many of the external functions used could be performed using base R code or through 'raster'/'terra' functions
#However, the use of additional packages substantially reduces run time, especially when applied to large rasters  
  #e.g., data.table::rbindlist(x) is faster than do.call(rbind, x), 
  #fasterize::fasterize(x) is much faster than raster::rasterize(x) for large rasters
  
#Nonetheless, this function can be quite slow when applied over large spatial extents, with the watershed transformation itself being the major bottleneck.
#I have tried implementing the procedure in Python, where the data preperation steps are much faster. 
#However, the watershed transform function from 'skimage' in Python does not offer noticeable improvement. 
#This is to be expected as EBImage calls C++ source code
#I have also found the results from EBImage::watershed to be much better and cleaner 
#e.g., skimage often segments long, relatively narrow areas of habitat into several independent features, 
#despite the width of the habitat never dropping below the minimum corridor width. 
#This issue can also be apparent in EBImage outputs and may be somewhat alleviated by filling small habitat gaps.

#The function may be considerably sped up by using a higher 'ext' value in the EBImage::watershed() call. 
#However, as this enables the algorithm to search for neighbouring habitat cells over a greater distance, 
#this often leads to messier, and arguably incorrect, delineations
#e.g., long thin strips of cells along the edges of one patch are often assigned to another, connected (and normally larger), patch when using ext > 1

###Required Packages###
  #'EBImage' (installed via 'BiocManager')
  #'dplyr'
  #'sf'
  #'raster'/'terra'
  #'stars'
  #'RANN'
  #'parallel' and 'doSNOW'
  #'smoothr'
  #'fasterize'



#####Function Code#####

#Install required packages
if (!require("EBImage")) install.packages("BiocManager")
BiocManager::install('EBImage')

if (!require("pacman")) install.packages("pacman")
p_load(EBImage, dplyr, sf, raster, stars, RANN, parallel, doSNOW, smoothr, fasterize)

#Delineation function
delineate <- function(lc_map, res_m, edge_depth, 
                     gap_area = NA, corridor_width) {
  
  suppressWarnings({
    
    #Convert measures to units of cells
    edge_depth = round(edge_depth/res_m)
    corridor_width = round((corridor_width/2)/res_m)
    
    #Create masks for: a) area of interest b) removing matrix cells
    area_mask <- mask(lc_map, lc_map, maskvalue = 0, updatevalue = 1)
    matrix_mask <- lc_map
    matrix_mask[matrix_mask == 0] <- NA
    
    #Fill in gaps within patches if desired
    if(!is.na(gap_area)){
      
      cat('Filling gaps...')
      
      #Convert raster to polygons and select only forest
      ccl_polys <- lc_map %>% 
        st_as_stars() %>% 
        st_as_sf(merge = T)
      names(ccl_polys)[1] <- 'Forest'
      ccl_polys <- ccl_polys[ccl_polys$Forest == 1,]
      
      #Set threshold for gaps to be removed
      threshold <- units::set_units(gap_area, m^2)
      
      #Split data into (n cores - 1) chunks
      cores <- detectCores()-1
      chunks <- split(ccl_polys, 
                             cut(seq_along(1:nrow(ccl_polys)), 
                                 cores, labels = F))
      
      #Fill gaps using parallel processing
      cl <- makeCluster(cores)
      registerDoSNOW(cl)
      polys_nogaps <- foreach(i = 1:cores, 
                              .packages = c('smoothr', 'sf'),
                              .options.snow = opts,
                              .inorder = F
      ) %dopar% { fill_holes(st_as_sf(chunks[[i]]), threshold) }
      
      stopCluster(cl)
      
      #Re-Rasterize data
      polys_nogaps <- st_as_sf(data.table::rbindlist(polys_nogaps))
      lc_nogaps <- fasterize(polys_nogaps, lc_map, background = 0)
      
      #Ensure extent remains the same
      lc_map <- mask(lc_nogaps, area_mask) 
      
      #Free up memory
      rm(c(ccl_polys, chunks, lc_nogaps, polys_nogaps)); gc(verbose = F)
      
    }
    
    #Convert to points of suitable & non-suitable habitat
    cat('\nFinding edge distances...')
    xy.nonsuit <- rasterToPoints(lc_map, function(x) x == 0)[,1:2]
    xy.suit <- rasterToPoints(lc_map, function(x) x == 1)[,1:2]
    
    #Find distance of each habitat cell from nearest matrix cell (edge distance)
    edge_dists <- RANN::nn2(data = xy.nonsuit, query = xy.suit, 
                            k = 1, treetype="kd",
                            searchtype = "standard")$nn.dists #euclidean distance
    
    #Create raster with edge distance in units of cells
    edge_dists <- rasterFromXYZ(cbind(xy.suit, 
                                      edge_dists/res(area_mask)[1])) 
    
    crs(edge_dists) <- crs(area_mask) #ensure crs is replaced
    edge_dists <- extend(edge_dists, extent(area_mask), value = NA) #ensure extent remains same
    
    #Free up memory
    rm(c(xy.suit, xy.nonsuit)); gc(verbose = F)
    
    #Threshold edge distances for watershed delineation
    #standardise all cells deeper than min corridor width to same value
    #Ensures contractions within large fragments aren't cut
    cat('\nStandardising edge distances...')
    edge_dists[is.na(edge_dists)] <- 0 #convert matrix to 0
    edge_dists[edge_dists > corridor_width] <- corridor_width + 2 #Assign same value to all cells further from edge than the specified corridor diameter
    dists_array <- as.array(edge_dists) #convert to array
    
    #Apply watershed transform to identify patches
    cat('\nWatershed delineation in progress - this may take a while...')
    ws_delineate <- EBImage::watershed(dists_array, tolerance = edge_depth, ext = 1)
    
    ws_raster <- ws_delineate %>% 
      as.data.frame() %>% 
      as.matrix() %>% 
      setValues(lc_map, .) %>% #convert to raster w/ same spatial attributes as original
      mask(matrix_mask) #ensure matrix is removed, undoes any addition of forest during gap filling
    
    #Create polygons for each patch
    polys <- ws_raster %>% 
      st_as_stars() %>% 
      st_as_sf(merge = T)
    polys$Fragment <- 1:nrow(polys)
    polys <- polys %>% dplyr::select(Fragment, geometry)
    
    #Ensure polygon numbering matches raster
    ws_raster <- fasterize::fasterize(polys, lc_map, field = 'Fragment') %>%
      mask(matrix_mask)
    
    #Summarise process and save
    patches <- ws_raster@data@max
    names(ws_raster) <- paste0(names(lc_map), '_Delineated')
    
    cat(paste0('\n', names(lc_map), ' delineated. Total of ', patches, ' fragments identified!'))
    output <- list(Landscape_Raster = ws_raster, Patch_Polygons = polys)
    
    return(output)
    gc()
    
  })
} 
