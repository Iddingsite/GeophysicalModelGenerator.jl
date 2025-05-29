# These are routes to perform waterflow calculations (upstream area etc.) on a DEM

using WhereTheWaterFlows
import WhereTheWaterFlows: waterflows

export waterflows

"""
    dlon, dlat = spacing(lon,lat)

Computes the spacing with central differences
"""
function spacing(lon, lat)
    dlon = zeros(size(lon.val)[1:2])
    dlat = zeros(size(lat.val)[1:2])
    @views dlon[2:(end - 1), :] = (lon.val[3:end, :, 1] - lon.val[1:(end - 2), :, 1]) / 2
    dlon[1, :] = dlon[2, :]
    dlon[end, :] = dlon[end - 1, :]
    dlat[:, 2:(end - 1)] = (lat.val[:, 3:end, 1] - lat.val[:, 1:(end - 2), 1]) / 2
    dlat[:, 1] = dlat[:, 2]
    dlat[:, end] = dlat[:, end - 1]

    return dlon, dlat
end

"""
    area_m2 = cell_area(Topo::GeoData)
Returns the cell area for a Topographic dataset in m² (required for upstream area calculation)
"""
function cell_area(Topo::GeoData)

    proj = ProjectionPoint(Lon = mean(Topo.lon.val[:]), Lat = mean(Topo.lat.val[:]))
    Topo_cart = convert2CartData(Topo, proj)
    dx, dy = spacing(Topo_cart.x, Topo_cart.y)

    area_m2 = dx .* dy * 1.0e6
    return area_m2
end


"""
    Topo_water, sinks, pits, bnds  = waterflows(Topo::GeoData;
        flowdir_fn=WhereTheWaterFlows.d8dir_feature, feedback_fn=nothing, drain_pits=true, bnd_as_sink=true,
        rainfall = nothing,
        minsize=300)

Takes a GMG GeoData object of a topographic map and routes water through the grid. Optionally,
you can specify `rainfall` in which case we accumulate the rain as specified in this 2D array instead of the cellarea.
This allows you to, for example, sum, up water if you have variable rainfall in the area.
The other options are as in the `waterflows` function of the package `WhereTheWaterFlows`.

Example
===
```julia-repl
# Download some topographic data
julia> Topo = import_topo([6.5,7.3,50.2,50.6], file="@earth_relief_03s");

# Flow the water through the area:
julia> Topo_water, sinks, pits, bnds  = waterflows(Topo)
julia> Topo_water
GeoData
  size      : (961, 481, 1)
  lon       ϵ [ 6.5 : 7.3]
  lat       ϵ [ 50.2 : 50.59999999999999]
  depth     ϵ [ 0.045 : 0.724]
  fields    : (:Topography, :area, :slen, :dir, :nout, :nin, :c)

```

"""
function waterflows(Topo::GeoData, flowdir_fn = WhereTheWaterFlows.d8dir_feature; feedback_fn = nothing, drain_pits = true, bnd_as_sink = true, rainfall = nothing, minsize = 300)

    cellarea = cell_area(Topo)
    cellarea_m2 = cellarea
    if !isnothing(rainfall)
        @assert typeof(rainfall) == Array{Float64, 2}
        cellarea = rainfall
    end

    dem = Topo.depth.val[:, :, 1]

    ni = size(Topo.depth.val)
    area = zeros(ni)
    slen = zeros(Int64, ni)
    dir = zeros(Int8, ni)
    nout = zeros(Int8, ni)
    nin = zeros(Int8, ni)
    c = zeros(Int64, ni)

    area[:, :, 1], slen[:, :, 1], dir[:, :, 1], nout[:, :, 1], nin[:, :, 1], sinks, pits, c[:, :, 1], bnds = waterflows(
        dem, cellarea, flowdir_fn;
        feedback_fn = feedback_fn, drain_pits = drain_pits, bnd_as_sink = bnd_as_sink
    )

    catchment_large = prune_catchments(c, minsize; val = 0)

    _, id_max = findmax(area)
    largest_catchment = catchment_large .== catchment_large[id_max]
    largest_area = copy(area)
    largest_area[.!largest_catchment] .= NaN

    log10_area = log10.(area)
    log10_largest_area = log10.(largest_area)

    Topo_water = addfield(Topo, (; area, slen, dir, nout, nin, c, cellarea_m2, catchment_large, log10_area, largest_catchment, largest_area, log10_largest_area))
    return Topo_water, sinks, pits, bnds
end
