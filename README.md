# BIOFRAG Habitat Fragment Delineation
An R function to implement the habitat fragment delineation method used by the BIOFRAG project (https://biofrag.wordpress.com/). Adapted from the original methodology created by M. Pfeifer, V. Lefebvre and R. Ewers (https://github.com/VeroL/BioFrag). 

## Background ##

Habitat fragments are most simply defined as isolated areas of suitable habitat, encompassed by a relatively inhospitable anthropogenic matrix. However, in many instances, patches of habitat may be connected to eachother by habitat corridors, which are of smaller diameter than the patches themselves. Whether two connected patches of habitat should be classified as one entity or two seperate fragments arguably depends on the level of functional connectivity provided by the connecting corridor/s. 

The level of functional connectivity that habitat corridors provide is largely determined by their width and degree of degradation, with narrow, degraded corridors often supporting only a depauperate biotic assemblage, similar to that of the matrix. However, traditional patch delineation methods, e.g., connected components labelling, group all connected habitat features into one fragment, regardless of the size of connecting corridors. Delineating habitat patches in this way could lead to the grouping of areas of habitat with limited functional connectivity and, in turn, result in misleading inference on the effects of any derived fragmentation metrics on biodiversity. 

This delineation procedure aims to overcome this potential issue by enabling researchers to incorporate ecological knowledge on taxa's edge related habitat preferences and habitat corridor use. 

N.B.: The terms 'Patch' and 'Fragment' are often used interchangeably in fragmentation ecology and could thus lead to some confusion in this vignette. So, I will use a dumbbell as a useful metaphor to hopefully clarify how I refer to 'patches', 'fragments' and 'corridors' - again, this terminology is admittedly not the most clear, but hopefully if you use this methodology you can just say 'We delineated habitat fragments using...' and not have to get into how elements are considered before and after delineation. 

Consider a dumbbell shaped piece of habitat. The narrow bar/grip is a 'habitat corridor' and the bulbous weights on either end are 'habitat patches' - the key difference between the elements is their width/diameter. 
<br/>
<p align="left">
<img src="https://user-images.githubusercontent.com/92942535/221232658-dcf2aa70-9c02-4ff4-b587-4417a0b2b0cb.png" width="300" height="300">
  <p align="right">
    <img src="https://user-images.githubusercontent.com/92942535/221234558-db90284e-00bc-4374-9104-d1ad76a60d4c.png" width="300" height="300">
<br/>
Then, once a delineation procedure has been applied and the habitat patches have either been grouped or seperated, I refer to the resultant classified elements as 'fragments'.  

## The Method ##

The method is based upon the watershed transformation commonly used in image segmentation, with a few prior steps added to improve ecological relevancy. These steps are centred around the extent of edge effects experienced by organisms residing within habitat patches; that is, the within-habitat distance from a matrix-habitat border over which microclimatic and biotic changes occur due to differences in climatic and biotic conditions within sorrounding matrix permeating into adjacent, natural habitat. This in turn leads to the concept of 'core' habitat - habitat which is far enough from the matrix that its biotic and abiotic conditions may be considered similar to those of natural, continuous habitat.

As in traditional delineation methods, this method defines entirely isolated habitat patches as independent fragments. However, the benefit of this procedure is that  habitat patches connected by corridors below a user-defined width are seperated into independent fragments, while patches connected by corridors above this width are grouped into a single fragment.  limited, especially in regard to the effects of corridor width. 

As the extent of edge effects often vary among taxa, it may be neccesary to conduct multiple delineations of the same landscape when conducting multi-taxa analyses.

The process consists of 6 key steps (see below figure for visual demonstration):
  - A) If required, a categorical land cover map for the focal landscape is converted to a binary habitat raster, where 1 = Habitat and 0 = Matrix.
  - B) The binary habitat raster is then converted to a distance matrix, with cell values representing the distance between each forest cell and the nearest matrix cell (i.e., distance to forest edge).
  - C) A distance threshod is applied, whereby all forest cells with an edge distance greater than pre-defined edge-effect distance are assigned the same value (here, the edge effect distance in units of raster cells, plus 2).
  - D) All local maxima below the pre-defined edge effect distance are flattened. This is equivalent to a H-Maxima transform and prevents small subsidiary areas of habitat that do not contain core habitat from being distinguished from larger, connected patches.
  - E) The resultant distance matrix is inverted (i.e., multiplied by -1), so that cell values decrease with increasing distance from the matrix.
  - F) The marker-controlled watershed transformation is applied. Conceptually, this fills the landscape with water, treating cell values as elevation, and identifies as distinct elements (i.e., habitat fragments) areas where the water pools. 
<br/>
<br/>
<p align="center">
<img src="https://user-images.githubusercontent.com/92942535/221204121-6f1c0896-a48a-437f-a505-bc33534ca3bd.png" width="550" height="700">
</p>
<br/>
<br/>

## Outputs ##
 
In the resulting output, independent habitat fragments are classified according to four criteria:

  1) Habitat patches that are entirely isolated are classed as independent fragments.
  2) Patches that contain core habitat and are connected by corridors that do not contain core habitat are seperated into 2+ independent fragments.
  3) Patches that are connected by corridors that do contain core habitat are grouped into one fragment.
  4) Patches that are not entirely isolated but do not themselves contain core habitat are grouped with the largest connected patch (i.e., into a single fragment). 
