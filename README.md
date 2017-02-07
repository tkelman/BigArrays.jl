# BigArrays.jl
storing and accessing large julia array using different backends.

# Features
- N dimension
- arbitrary data type
- arbitrary subset cutout (saving should be chunk size aligned)
- extensible with multiple backends
- arbitrary shape, the dataset boundary can be curve-like
- arbitrary dataset size (in theory, tested dataset size: ~ 9 TB)
- support negative coordinates
- chunk compression

## Installation
    Pkg.clone("https://github.com/seung-lab/BigArrays.jl.git")
    
## usage

```julia
using BigArrays.H5sBigArrays
ba = H5sBigArray("/directory/of/hdf5/files/");
# use it as normal array

ba[101:200, 201:300, 1:3] = rand(UInt8, 100,100,3)
@show ba[101:200, 201:300, 1:3]
```

`BigArrays` do not have limit of dataset size, if your reading index is outside of existing file range, will return an array filled with zeros.
   
## supported backends
- [x] hdf5 files. 
- [x] seunglab aligned 2D image hdf5 files.
- [x] cuboids in AWS S3 or Google Cloud Storage
- [x] [Janelia DVID](https://github.com/janelia-flyem/dvid)
- [ ] [google subvolume](https://developers.google.com/brainmaps/v1beta2/rest/v1beta2/volumes/subvolume)
- [ ] [JPL BOSS](https://github.com/jhuapl-boss)
- [ ] [KLB](http://www.nature.com/nprot/journal/v10/n11/abs/nprot.2015.111.html), [the repo](https://bitbucket.org/fernandoamat/keller-lab-block-filetype)
