# BIOFRAG Habitat Fragment Delineation
R code to implement the habitat fragment delineation method used by the BIOFRAG project (https://biofrag.wordpress.com/). Adapted from the original methodology created by M. Pfeifer, V. Lefebvre and R. Ewers (https://github.com/VeroL/BioFrag). 

## Background ##

Habitat fragments are most simply defined as isolated areas of suitable habitat, encompassed by a relatively inhospitable anthropogenic matrix. However, in many instances, patches of habitat may be connected to eachother by habitat corridors, generally of smaller diameter than the patches themselves. Whether two connected patches of habitat should be classified as one entity or two seperate fragments arguably depends on the level of functional connectivity provided by the connecting corridor/s. 

The level of functional connectivity that habitat corridors provide is largely determined by their width and degree of degradation, with narrow, degraded corridors often supporting only a depauperate biotic assemblage, similar to that of the matrix. However, traditional patch delineation methods, e.g., connected components labelling, group all connected habitat features into one fragment, regardless of the size of connecting corridors. Delineating habitat patches without consideration of the size of corridors could thus lead to the grouping of areas of habitat with limited functional connectivity and, in turn, result in misleading inference on the effects of any derived fragmentation metrics on biodiversity. 

This delineation procedure aims to overcome this potential issue by enabling researchers to incorporate ecological knowledge on species'/taxa's edge related habitat preferences and habitat corridor use. 

## The Method ##

To enable . 

The process consists of 6 key steps (see below figure for visual demonstration):
  - A) If required, a categorical land cover map for the focal landscape is converted to a binary habitat raster, where 1 = Habitat and 0 = Matrix.
  - B) The binary habitat raster is then converted to a distance matrix, with cell values representing the distance between each forest cell and the nearest matrix cell (i.e., distance to forest edge).
  - C) A distance threshod is applied, whereby all forest cells further from an edge than a pre-defined edge effect distance are assigned the same value (here, the edge effect distance in units of raster cells, plus 2).
  - D) All local maxima below the pre-defined edge effect distance are flattened. This is equivalent to a H-Maxima transform and prevents small subsidiary areas of habitat that do not contain core habitat from being distinguished from larger, connected patches.
  - E) The resultant distance matrix is inverted (i.e., multiplied by -1), so that cells far from a forest edge hold lower values and cells close to a forest edge hold higher values.
  - F) The marker-controlled watershed transformation is applied. Conceptually, this fills the landscape with water, treating cell values as elevation, and identifies as distinct elements (i.e., forest patches) areas where the water pools. 
<br/>
<br/>
<p align="center">
<img src="https://user-images.githubusercontent.com/92942535/221204121-6f1c0896-a48a-437f-a505-bc33534ca3bd.png" width="450" height="600">
</p>
<br/>
<br/>

## Outputs ##
 
In the resulting output, independent habitat fragments are classified according to four criteria:

  1) Habitat patches that are entirely isolated are classed as independent fragments.
  2) Patches that contain core habitat and are connected by corridors that do not contain core habitat are seperated into 2+ independent fragments.
  3) Patches that are connected by corridors that do contain core habitat are grouped into one fragment.
  4) Patches that are not entirely isolated but do not themselves contain core habitat are grouped with the largest connected patch (i.e., into a single fragment). 
