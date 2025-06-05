<h1> <img src="./assets/GMG_Logo_new_noText.png" alt="GeophysicalModelGenerator.jl" width="50"> GeophysicalModelGenerator.jl </h1>

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliageodynamics.github.io/GeophysicalModelGenerator.jl/dev)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliageodynamics.github.io/GeophysicalModelGenerator.jl/dev/)
[![Build Status](https://github.com/JuliaGeodynamics/GeophysicalModelGenerator.jl/workflows/CI/badge.svg)](https://github.com/JuliaGeodynamics/GeophysicalModelGenerator.jl/actions)
[![codecov](https://codecov.io/gh/JuliaGeodynamics/GeophysicalModelGenerator.jl/graph/badge.svg?token=2gEdE0nfSh)](https://codecov.io/gh/JuliaGeodynamics/GeophysicalModelGenerator.jl)
[![DOI](https://zenodo.org/badge/366377223.svg)](https://zenodo.org/doi/10.5281/zenodo.8074345)
[![DOI](https://joss.theoj.org/papers/10.21105/joss.06763/status.svg)](https://doi.org/10.21105/joss.06763)

<p align="center"><img src="./assets/GMG_Logo_new.png" alt="GeophysicalModelGenerator.jl" width="400"></p>

Creating consistent 3D images of geophysical and geological datasets and turning that into an input model for geodynamic simulations is often challenging. The aim of this package is to help with this, by providing a number of routines to easily import data and create a consistent 3D visualisation from it in the VTK-toolkit format, which can for example be viewed with [Paraview](https://www.paraview.org). In addition, we provide a range of tools that helps to generate input models to perform geodynamic simulations and import the results of such simulations back into julia.

A short summary of the package and its features are given below. For a detailed description of the package and to learn how to use it, have a look at the [documentation](https://juliageodynamics.github.io/GeophysicalModelGenerator.jl/dev/).

![README_img](./docs/src/assets/img/Readme_pic.png)
### Contents
- [Geophysical Model Generator](#geophysical-model-generator)
    - [Contents](#contents)
  - [Main features](#main-features)
  - [Usage](#usage)
  - [Installation](#installation)
  - [Dependencies](#dependencies)
  - [Visualising Alpine data](#visualising-alpine-data)
  - [Contributing](#contributing)
  - [Funding](#funding)

## Main features
Some of the key features are:
- Create 3D volumes of seismic tomography models.
- Handle 2D data (e.g., along a cross-section), including surfaces such as the Moho depth.
- Plot data along lines (e.g., drillholes) or at points (e.g., earthquake locations, GPS velocities).
- Handle both scalar and vector data sets.
- Grab screenshots of cross-sections or maps in published papers and view them in 3D (together with other data).
- Create a consistent overview that includes all available data of a certain region.
- Create initial model setups for the 3D geodynamic code [LaMEM](https://github.com/UniMainzGeo/LaMEM).
- Import LaMEM timesteps.

All data is transformed into either a `GeoData` or a `UTMData`  structure which contains info about `longitude/latitude/depth`, `ew/ns/depth` coordinates along with an arbitrary number of scalar/vector datasets, respectively. All data can be exported to Paraview with the `write_paraview` routine, which transfers the data to a `ParaviewData` structure (that contains Cartesian Earth-Centered-Earth-Fixed (ECEF) `x/y/z` coordinates, used for plotting)

## Usage
The best way to learn how to use this is to install the package (see below) and look at the tutorials in the [manual](https://juliageodynamics.github.io/GeophysicalModelGenerator.jl/dev/).

## Installation
First, you need to install julia on your machine. We recommend to use the binaries from [https://julialang.org](https://julialang.org).
Next, start julia and switch to the julia package manager using `]`, after which you can add the package.
```julia-repl
julia> ]
(@1.6) pkg> add GeophysicalModelGenerator
```
You can test whether it works on your system with
```julia-repl
julia> ]
(@1.6) pkg> test GeophysicalModelGenerator
```
and use it with
```julia-repl
julia> using GeophysicalModelGenerator
```

## Dependencies
We rely on a number of additional packages, which are all automatically installed.
- [GeoParams.jl](https://github.com/JuliaGeodynamics/GeoParams.jl) Defines dimensional units, and makes it easy to convert for km/s to m/s, etc.
- [WriteVTK.jl](https://github.com/jipolanco/WriteVTK.jl) writes VTK files (to be opened with Paraview).
- [ImageIO.jl](https://github.com/JuliaIO/ImageIO.jl), [FileIO.jl](https://github.com/JuliaIO/FileIO.jl), [Colors.jl](https://github.com/JuliaGraphics/Colors.jl) to import screenshots from papers.
- [Interpolations.jl](https://github.com/JuliaMath/Interpolations.jl) for interpolations (for example related to importing screenshots).


## Visualising Alpine data
We have used this package to interpret various data sets of the Alps (mostly openly available, sometimes derived from published papers). You can download the resulting paraview files here (using the `*.vts` format), where we also included the julia scripts to do the work (some of which are also described in more detail in the tutorials). Just unzip the files and open the corresponding `*.vts` in Paraview.

[https://seafile.rlp.net/d/22b0fb85550240758552/](https://seafile.rlp.net/d/22b0fb85550240758552/)

If you want your data be included here as well, give us an email (or even better: send the files with julia scripts).

## Contributing
You are very welcome to request new features and point out bugs by opening an issue. You can also help by adding features and creating a pull request.

## Citing
If you find this package useful, please cite this paper:

Kaus B.J.P., Thielmann M., Aellig P., De Montserrat A., De Siena L., Frasunkiewicz J., Fuchs L., Piccolo A., Ranocha H., Riel N., Schuler C., Spang A., Weiler T. (2024).  GeophysicalModelGenerator.jl: A Julia package to visualise geoscientific data and create numerical model setups. *Journal of Open Source Software*. 9(102), 6763. https://doi.org/10.21105/joss.06763.


## Funding
Development of this software package was funded by the German Research Foundation (DFG grants TH2076/7-1 and KA3367/10-1), which are part of the [SPP 2017 4DMB project](http://www.spp-mountainbuilding.de) project, the DFG Emmy Noether grant TH 2076/8-1, by the European Research Council under grant ERC CoG #771143 - [MAGMA](https://magma.uni-mainz.de) and by the German Ministry of Science and Education (BMBF) as part of project DEGREE. The project was initiated at a [Terrestrial Magmatic Systems - TeMaS](https://temas.uni-mainz.de) workshop with researchers from Frankfurt and Mainz where we realized that it is way too time-consuming to collect and visualise available data of a certain region.
