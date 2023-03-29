#Function to calculate the BIOFRAG patch shape complexity (termed compactness) index. 
#This was designed to minimise correlation between patch size and patch shape
#The formula is based on the relative length of the maximum chord of a patch polygon 
#and the diameter of a circle of equivalent area
#The metric has a lower bound of 1 (indicating a patch is maximally compact, i.e., circular)
#Higher values indicate greater patch shape complexity

compactness <- function(polygon){

  #Get polygon coordinates
  poly_crs <- crs(polygon)
  poly_noholes <- sf_remove_holes(polygon) #Remove holes to ensure maximum chord calculation only considers outer limits of patch
  xy = st_coordinates(poly_noholes)[,1:2]
  
  #Compute the distance matrix and find the two points within the patch that are furthest apart
  df_dist = Rfast::Dist(xy)
  v = which.max(m) - 1
  maxij = c(v %% nrow(m)+1, v %/% nrow(m)+1)
  
  #Define the largest chord
  chord = rbind(xy[maxij[1],], xy[maxij[2],])
  chord <- SpatialPoints(chord, proj4string = poly_crs)
  chord <- spTransform(chord, 'EPSG:4326')
  
  #Find great circle distance of chord
  chord_length <- distGeo(chord[1,], chord[2,])
  
  area <- as.numeric(st_area(polygon))
  compac <- length/(2*(sqrt(area/pi)))
  
  return(compac)
  gc(verbose = F)
  
} 
