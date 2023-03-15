# few utils that are useful 

export meshgrid, CrossSection, CrossSectionVolume, CrossSectionSurface, CrossSectionPoints, ExtractSubvolume, SubtractHorizontalMean
export ParseColumns_CSV_File, AboveSurface, BelowSurface, VoteMap
export InterpolateDataOnSurface, InterpolateDataFields2D, InterpolateDataFields
export RotateTranslateScale
export DrapeOnTopo, LithostaticPressure!

using NearestNeighbors

"""
    meshgrid(vx,vy,vz)

Computes an (x,y,z)-grid from the vectors (vx,vy,vz).
For more information, see the MATLAB documentation.
"""
function meshgrid(vx::AbstractVector{T}, vy::AbstractVector{T},
                     vz::AbstractVector{T}) where {T}
    m, n, o = length(vy), length(vx), length(vz)
    vx = reshape(vx, 1, n, 1)
    vy = reshape(vy, m, 1, 1)
    vz = reshape(vz, 1, 1, o)
    om = ones(Int, m)
    on = ones(Int, n)
    oo = ones(Int, o)
    (vx[om, :, oo], vy[:, on, oo], vz[om, on, :])
end

""" 
CrossSectionVolume(Volume::GeoData; dims=(100,100), Interpolate=false, Depth_level=nothing; Lat_level=nothing; Lon_level=nothing; Start=nothing, End=nothing )

Creates a cross-section through a volumetric (3D) `GeoData` object. 

- Cross-sections can be horizontal (map view at a given depth), if `Depth_level` is specified
- They can also be vertical, either by specifying `Lon_level` or `Lat_level` (for a fixed lon/lat), or by defining both `Start=(lon,lat)` & `End=(lon,lat)` points.
- `Interpolate` indicates whether we want to simply extract the data from the 3D volume (default) or whether we want to linearly interpolate it on a new grid, which has dimensions as specified in `dims`

# Example:
```julia-repl
julia> Lon,Lat,Depth   =   LonLatDepthGrid(10:20,30:40,(-300:25:0)km);
julia> Data            =   Depth*2;                # some data
julia> Vx,Vy,Vz        =   ustrip(Data*3),ustrip(Data*4),ustrip(Data*5);
julia> Data_set3D      =   GeoData(Lon,Lat,Depth,(Depthdata=Data,LonData=Lon, Velocity=(Vx,Vy,Vz))); 
julia> Data_cross      =   CrossSectionVolume(Data_set3D, Depth_level=-100km)  
GeoData 
  size  : (11, 11, 1)
  lon   ϵ [ 10.0 : 20.0]
  lat   ϵ [ 30.0 : 40.0]
  depth ϵ [ -100.0 km : -100.0 km]
  fields: (:Depthdata, :LonData, :Velocity)
```



"""
function CrossSectionVolume(V::AbstractGeneralGrid; dims=(100,100), Interpolate=false, Depth_level=nothing, Lat_level=nothing, Lon_level=nothing, Start=nothing, End=nothing )

    DataSetType = CheckDataSet(V);

    if DataSetType != 3
        error("CrossSectionVolume: the input data set has to be a volume!")
    end

    X,Y,Z = coordinate_grids(V)

    if !isnothing(Depth_level)    # Horizontal slice
        CheckBounds(Z, Depth_level)    
        if Interpolate
            Lon,Lat,Depth = LonLatDepthGrid(    LinRange(minimum(X), maximum(X), dims[1]),
                                                LinRange(minimum(Y), maximum(Y), dims[2]),
                                                Depth_level)
        else
            ind_z   =   argmin(abs.(NumValue(Z[1,1,:]) .- Depth_level.val))
            iDepth  =   ind_z:ind_z;
            iLon    =   1:size(NumValue(X),1);
            iLat    =   1:size(NumValue(Y),2);
        end
    end

    if !isnothing(Lat_level)   # vertical slice @ given latitude
        CheckBounds(Y, Lat_level)    
        if Interpolate
            Lon,Lat,Depth = LonLatDepthGrid(    LinRange(minimum(X), maximum(X), dims[1]),
                                                Lat_level,
                                                LinRange(minimum(Z), maximum(Z), dims[2]))
        else
            ind_l   =   argmin(abs.(Y[1,:,1] .- Lat_level))
            iDepth  =   1:size(Z,3)
            iLon    =   1:size(X,1);
            iLat    =   ind_l:ind_l
        end
    end

    if !isnothing(Lon_level)   # vertical slice @ given longitude
        CheckBounds(X, Lon_level)    
        if Interpolate 
            Lon,Lat,Depth = LonLatDepthGrid(    Lon_level,
                                                LinRange(minimum(Y), maximum(Y), dims[1]),
                                                LinRange(minimum(Z), maximum(Z), dims[2]))
        else
            ind_l   =   argmin(abs.(X[:,1,1] .- Lon_level))
            iDepth  =   1:size(Z,3)
            iLat    =   1:size(Y,2);
            iLon    =   ind_l:ind_l
        end
    end

    # diagonal profile defined by start and end lon/lat points
    if !isnothing(Start)
        if isnothing(End)
            error("Also define End coordinates if you indicate starting lon/lat value")
        end
        Interpolate = true; # we must interpolate in this case

        Lon_dum,Lat_p,Depth_p = LonLatDepthGrid(    Start[1],
                                                LinRange(Start[2], End[2], dims[1]),
                                                LinRange(minimum(Z), maximum(Z), dims[2]))

        Lon_p,Lat_dum,Depth = LonLatDepthGrid(    LinRange(Start[1], End[1], dims[1]),
                                                Start[2],
                                                LinRange(minimum(Z), maximum(Z), dims[2]))

        Lon             =   zeros(dims[1],dims[2],1)
        Lat             =   zeros(dims[1],dims[2],1)
        Depth           =   zeros(dims[1],dims[2],1)*Depth_p[1]
        
        # We need 3D matrixes for the paraview writing routine to know we are in 3D
        Lon[:,:,1]      =   Lon_p[:,1,:]
        Lat[:,:,1]      =   Lat_p[1,:,:]
        Depth[:,:,1]    =   Depth_p[1,:,:]
        
    end

    if Interpolate
        # Interpolate data on profile
        DataProfile = InterpolateDataFields(V, Lon, Lat, Depth);    
    else
        # extract data (no interpolation)
        DataProfile = ExtractDataSets(V, iLon, iLat, iDepth);
    end

    return DataProfile

end


""" 
CrossSectionSurface(Surface::GeoData; dims=(100,), Interpolate=false, Depth_level=nothing; Lat_level=nothing; Lon_level=nothing; Start=nothing, End=nothing )

Creates a cross-section through a surface (2D) `GeoData` object.

- Cross-sections can be horizontal (map view at a given depth), if `Depth_level` is specified
- They can also be vertical, either by specifying `Lon_level` or `Lat_level` (for a fixed lon/lat), or by defining both `Start=(lon,lat)` & `End=(lon,lat)` points.

- IMPORTANT: The surface to be extracted has to be given as a gridded GeoData object. It may also contain NaNs where it is not defined. Any points lying outside of the defined surface will be considered NaN.

# Example:
```julia-repl
julia> Lon,Lat,Depth   =   LonLatDepthGrid(10:20,30:40,-50km);
julia> Data            =   Depth*2;                # some data
julia> Vx,Vy,Vz        =   ustrip(Data*3),ustrip(Data*4),ustrip(Data*5);
julia> Data_set2D      =   GeoData(Lon,Lat,Depth,(Depth=Depth,)); 
julia> Data_cross      =   CrossSectionSurface(Data_set2D, Lat_level =15)  
GeoData 
  size  : (11, 11, 1)
  lon   ϵ [ 10.0 : 20.0]
  lat   ϵ [ 30.0 : 40.0]
  depth ϵ [ -100.0 km : -100.0 km]
  fields: (:Depthdata, :LonData, :Velocity)
```



"""
function CrossSectionSurface(S::AbstractGeneralGrid; dims=(100,), Interpolate=true, Depth_level=nothing, Lat_level=nothing, Lon_level=nothing, Start=nothing, End=nothing )

    DataSetType = CheckDataSet(S);
    if DataSetType != 2
        error("CrossSectionSurface: the input data set has to be a surface!")
    end

    X,Y,Z = coordinate_grids(S)
    
    Lon_vec = X[:,1,1]
    Lat_vec = Y[1,:,1]

    if !isnothing(Depth_level)    # not working yet, as this requires the intersection of two interfaces
        error(" horizontal cross sections not working yet with surface data!")
    end

    if !isnothing(Lat_level)   # vertical slice @ given latitude
        # create a vector that spans the entire dataset @ a given latitutde
        Lon = LinRange(minimum(Lon_vec), maximum(Lon_vec), dims[1])
        Lat = ones(size(Lon))*Lat_level;
    end

    if !isnothing(Lon_level)   # vertical slice @ given longitude
        # create a vector that spans the entire dataset @ a given longitude
        Lat = LinRange(minimum(Lat_vec), maximum(Lat_vec), dims[1])
        Lon = ones(size(Lat))*Lon_level
    end

    # diagonal profile defined by start and end lon/lat points
    if !isnothing(Start)
        if isnothing(End)
            error("Also define End coordinates if you indicate starting lon/lat value")
        end

        Lon = LinRange(Start[1], End[1], dims[1])
        Lat = LinRange(Start[2], End[2], dims[1]);
    end

    # now interpolate the depth information of the surface to the profile in question
    interpol    =   linear_interpolation((Lon_vec, Lat_vec), Z[:,:,1],extrapolation_bc=NaN);  # create interpolation object, fill with NaNs if outside
    depth_intp   =   interpol.(Lon, Lat)*km

    # also interpolate any other data that is stored in the GeoData structure on the profile
    fields_new  = S.fields;
    field_names = keys(fields_new);
    for i = 1:length(S.fields)
        if typeof(S.fields[i]) <: Tuple
            # vector or anything that contains more than 1 field
            data_tuple = fields_new[i]      # we have a tuple (likely a vector field), so we have to loop 
            data_array = zeros(size(Lon,1),size(Lon,2),length(data_tuple));     # create a 2D array that holds the 2D interpolated values
            unit_array = zeros(size(data_array));

            for j=1:length(data_tuple)
                interpol    =   linear_interpolation((Lon_vec, Lat_vec), dropdims(ustrip.(data_tuple[j]),dims=3),extrapolation_bc = NaN);      # create interpolation object
                data_array[:,:,j] =   interpol.(Lon, Lat);          
            end
            data_new    = tuple([data_array[:,:,c] for c in 1:size(data_array,3)]...)     # transform 3D matrix to tuple, do not add unit, as this creates an error in GMG (Issue), to add the unit: *unit(S.fields[i][1][1])

        else
            # scalar field
            interpol    =   linear_interpolation((Lon_vec, Lat_vec), dropdims(ustrip.(S.fields[i]),dims=3), extrapolation_bc = NaN);
            data_new    =   interpol.(Lon, Lat)*unit(S.fields[i][1]);                                                 # interpolate data field
        end
        
        # replace the field 
        new_field   =   NamedTuple{(field_names[i],)}((data_new,))                          # Create a tuple with same name and unit
        fields_new  =   merge(fields_new, new_field);                                       # replace the field in fields_new
        
    end
    
    # create GeoData structure with the interpolated points
    Data_profile = GeoData(Lon, Lat, depth_intp, (fields_new));

    return Data_profile
end


"""
    function CrossSectionPoints(P::GeoData; Depth_level=nothing, Lat_level=nothing, Lon_level=nothing, Start=nothing, End=nothing, section_width=50 )
    
Creates a projection of separate points (saved as a GeoData object) onto a chosen plane. Only points with a maximum distance of section_width are taken into account

"""
function CrossSectionPoints(P::GeoData; Depth_level=nothing, Lat_level=nothing, Lon_level=nothing, Start=nothing, End=nothing, section_width = 10km)
    
    DataSetType = CheckDataSet(P);
    if DataSetType != 1
        error("CrossSectionPoints: the input data set has to be a pointwise data set!")
    end

    if !isnothing(Depth_level) 
        ind = findall(-0.5*section_width .< (P.depth - Depth_level) .< 0.5*section_width) # find all points around the desired depth level, both units shoud be in km, so no unit transformation required

        # create temporary variables
        lon_tmp     = P.lon.val[ind]*P.lon.unit
        lat_tmp     = P.lat.val[ind]*P.lat.unit
        depth_tmp   = P.depth.val[ind]*P.depth.unit
        depth_proj  = ones(size(depth_tmp))*Depth_level

        # create fields that will be stored additionally on the GeoData structure
        field_tmp = (depth_proj=depth_proj,lat_proj=lat_tmp,lon_proj=lon_tmp) # these are the projected points

    end

    if !isnothing(Lat_level)   # vertical slice @ given latitude

        p_Point = ProjectionPoint(Lat=Lat_level,Lon=sum(P.lon.val)/length(P.lon.val)) # define the projection point (lat/lon) as the latitude and the mean of the longitudes of the data
        P_UTM   = Convert2UTMzone(P, p_Point) # convert to UTM        
        ind     = findall(-0.5*ustrip(uconvert(u"m",section_width)) .< (P_UTM.NS.val .- p_Point.NS) .< 0.5*ustrip(uconvert(u"m",section_width))) # find all points around the desired latitude level, UTM is in m, so we have to convert the section width

        # create temporary variables
        lon_tmp     = P.lon.val[ind]*P.lon.unit
        lat_tmp     = P.lat.val[ind]*P.lat.unit
        depth_tmp   = P.depth.val[ind]*P.depth.unit
        lat_proj    = ones(size(depth_tmp))*Lat_level

        # data to be stored on the new GeoData structure
        field_tmp = (depth_proj=depth_tmp,lat_proj=lat_proj,lon_proj=lon_tmp) # these are the projected points

    end

    if !isnothing(Lon_level)   # vertical slice @ given longitude
        p_Point = ProjectionPoint(Lat=sum(P.lat.val)/length(P.lat.val),Lon=Lon_level) # define the projection point (lat/lon) as the latitude and the mean of the longitudes of the data
        P_UTM   = Convert2UTMzone(P,p_Point) # convert to UTM
        ind     = findall(-0.5*ustrip(uconvert(u"m",section_width)) .< (P_UTM.EW.val .- p_Point.EW) .< 0.5*ustrip(uconvert(u"m",section_width))) # find all points around the desired longitude level, UTM is in m, so we have to convert the section width

        # create temporary variables
        lon_tmp     = P.lon.val[ind]*P.lon.unit
        lat_tmp     = P.lat.val[ind]*P.lat.unit
        depth_tmp   = P.depth.val[ind]*P.depth.unit
        lon_proj    = ones(size(depth_tmp))*Lon_level

        # create fields that will be stored on the GeoData structure
        field_tmp = (depth_proj=depth_tmp,lat_proj=lat_tmp,lon_proj=lon_proj) # these are the projected points

    end

    # vertical profile defined by start and end lon/lat points
    # here we need to compute the distance to a distance_to_plane
    # also, we need to project the points on the profile plane for later plotting
    if !isnothing(Start)
        if isnothing(End)
            error("Also define End coordinates if you indicate starting lon/lat value")
        end

        # choose projection point based on Start and End coordinates of the profile
        p_Point = ProjectionPoint(Lat=0.5*(Start[2]+End[2]),Lon=0.5*(Start[1]+End[1]))
    
        # convert P to UTM Data
        P_UTM = Convert2UTMzone(P, p_Point) # convert to UTM

        # create a GeoData set containing the points that create the profile plane (we need three points to uniquely define that plane)
        # here, we define the points in a way that the angle between P1-P2 and P1-P3 vectors is 90° --> useful for the cross product
        Profile     = GeoData([Start[1] Start[1]  End[1]], [Start[2]  Start[2] End[2]], [0 -200 0]*km, (depth = [0 -200 0]*km,))
        Profile_UTM = Convert2UTMzone(Profile,p_Point) # convert to UTM

        # compute the unit normal of the profile plane using the cross product
        # ATTENTION: UTM COORDINATES ARE IN M, WHILE DEPTH IS IN KM !!!
        a1 = Profile_UTM.EW.val[2]-Profile_UTM.EW.val[1]
        a2 = Profile_UTM.NS.val[2]-Profile_UTM.NS.val[1]
        a3 = (Profile_UTM.depth.val[2]- Profile_UTM.depth.val[1]) * 1e3

        b1 = Profile_UTM.EW.val[3]- Profile_UTM.EW.val[1]
        b2 = Profile_UTM.NS.val[3]- Profile_UTM.NS.val[1]
        b3 = (Profile_UTM.depth.val[3]- Profile_UTM.depth.val[1]) * 1e3

        nx = a2*b3 - a3*b2
        ny = a3*b1 - a1*b3
        nz = a1*b2 - a2*b1

        t = (nx*Profile_UTM.EW.val[1] .- nx*P_UTM.EW.val .+ ny*Profile_UTM.NS.val[1] .- ny*P_UTM.NS.val .+ nz*Profile_UTM.depth.val[1]*1e3 .- nz*P_UTM.depth.val*1e3)/(nx*nx+ny*ny+nz*nz)

        # compute the distance to the plane 
        dist  = sqrt.((t.*nx).^2 + (t.*ny).^2 + (t.*nz).^2)

        # find the points that are within the required window around the profile
        ind     = findall(-0.5*ustrip(uconvert(u"m",section_width)) .< dist .< 0.5*ustrip(uconvert(u"m",section_width))) # find all points around the profile (distance is treated in m)

        # project the points on the plane (only the relevant ones)
        px = P_UTM.EW.val[ind]           + t[ind].*nx
        py = P_UTM.NS.val[ind]           + t[ind].*ny
        pz = P_UTM.depth.val[ind]*1e3    + t[ind].*nz # convert depth to m

        # the projected points are given in UTM coordinates and not in lon/lat/depth
        # therefore we have to recompute the lat/lon/depth values of the projected points
        # then we will return a GeoData structure with all information included
        trans = LLAfromUTM(p_Point.zone, p_Point.isnorth, wgs84) # set up transformation

        plon   = zeros(size(ind));
        plat   = zeros(size(ind));
        pdepth = zeros(size(ind));

        for i in eachindex(ind)
            utmi  = UTM(px[i],py[i],pz[i])
            llai  = trans(utmi)
            plon[i]     = llai.lon
            plat[i]     = llai.lat
            pdepth[i]   = llai.alt
        end

        # data to be stored in the GeoData structure --> projected lon/lat, but also UTM coordinates
        field_tmp = (depth_proj=pdepth/1e3,lat_proj=plat,lon_proj=plon) # these are the projected points, depth is in km!!!
    end

    # also transfer any other data that is stored in the GeoData structure
    fields_new  = P.fields;
    field_names = keys(fields_new);
    for i = 1:length(P.fields)
        if typeof(P.fields[i]) <: Tuple
            # vector or anything that contains more than 1 field
            data_tuple = fields_new[i]      # we have a tuple (likely a vector field), so we have to loop 
            data_array = zeros(size(ind,1),length(data_tuple));     # create a 2D array that holds the chosen values

            for j=1:length(data_tuple)
                data_array[:,j] = ustrip.(data_tuple[i][ind])          
            end
            data_new    = tuple([data_array[:,:,c] for c in 1:size(data_array,3)]...)     # transform 2D matrix to tuple, do not consider the unit as it creates an error in GMG (Issue), to add the unit: *unit.(P.fields[i][1][1]
    
        else
            # scalar field
            data_new    =   fields_new[i][ind];                                                 # interpolate data field
        end
            
        # replace the field 
        new_field   =   NamedTuple{(field_names[i],)}((data_new,))                          # Create a tuple with same name and unit
        fields_new  =   merge(fields_new, new_field);                                       # replace the field in fields_new
            
    end
    
    # merge old and new fields
    fields_new = merge(fields_new,field_tmp);

    # create a GeoData structure to return
    Data_profile = GeoData(P.lon.val[ind],P.lat.val[ind],P.depth.val[ind],(fields_new))


    return Data_profile
end

"""
    CrossSection(DataSet::GeoData; dims=(100,100), Interpolate=false, Depth_level=nothing; Lat_level=nothing; Lon_level=nothing; Start=nothing, End=nothing )

Creates a cross-section through a `GeoData` object. 

- Cross-sections can be horizontal (map view at a given depth), if `Depth_level` is specified
- They can also be vertical, either by specifying `Lon_level` or `Lat_level` (for a fixed lon/lat), or by defining both `Start=(lon,lat)` & `End=(lon,lat)` points.
- Depending on the type of input data (volume, surface or point data), cross sections will be created in a different manner:
1. Volume data: data will be interpolated or directly extracted from the data set.
2. Surface data: surface data will be interpolated or directly extracted from the data set
3. Point data: data will be projected to the chosen profile. Only data within a chosen distance (default is 50 km) will be used

- `Interpolate` indicates whether we want to simply extract the data from the data set (default) or whether we want to linearly interpolate it on a new grid, which has dimensions as specified in `dims` NOTE: THIS ONLY APPLIES TO VOLUMETRIC aND SURFACE DATA SETS
- 'section_width' indicates the maximal distance within which point data will be projected to the profile

# Example:
```julia-repl
julia> Lon,Lat,Depth   =   LonLatDepthGrid(10:20,30:40,(-300:25:0)km);
julia> Data            =   Depth*2;                # some data
julia> Vx,Vy,Vz        =   ustrip(Data*3),ustrip(Data*4),ustrip(Data*5);
julia> Data_set3D      =   GeoData(Lon,Lat,Depth,(Depthdata=Data,LonData=Lon, Velocity=(Vx,Vy,Vz))); 
julia> Data_cross      =   CrossSection(Data_set3D, Depth_level=-100km)  
GeoData 
  size  : (11, 11, 1)
  lon   ϵ [ 10.0 : 20.0]
  lat   ϵ [ 30.0 : 40.0]
  depth ϵ [ -100.0 km : -100.0 km]
  fields: (:Depthdata, :LonData, :Velocity)
```

"""
function CrossSection(DataSet::AbstractGeneralGrid; dims=(100,100), Interpolate=false, Depth_level=nothing, Lat_level=nothing, Lon_level=nothing, Start=nothing, End=nothing, section_width=50km)

    DataSetType = CheckDataSet(DataSet); # check which kind of data set we are dealing with

    if DataSetType==1 # points
        DataProfile = CrossSectionPoints(DataSet; Depth_level, Lat_level, Lon_level, Start, End, section_width)    
    elseif DataSetType==2 # surface
        DataProfile = CrossSectionSurface(DataSet; dims, Depth_level, Lat_level, Lon_level, Start, End)
    elseif DataSetType==3 # volume 
        DataProfile = CrossSectionVolume(DataSet; dims, Interpolate, Depth_level, Lat_level, Lon_level, Start, End)
    end

    return DataProfile

end



"""
    ExtractSubvolume(V::GeoData; Interpolate=false, Lon_level=nothing, Lat_level=nothing, Depth_level=nothing, dims=(50,50,50))

Extract or "cuts-out" a piece of a 2D or 3D GeoData set, defined by `Lon`, `Lat` and `Depth` coordinates.

This is useful if you are only interested in a part of a much bigger larger data set.

- `Lon_level`,`Lat_level` and `Depth_level` should be tuples that indicate `(minimum_value, maximum_value)` along the respective direction. If not specified we use the full range. 
- By default, `Interpolate=false` and we find the closest indices within the data set (so your new data set will not go exactly from minimum to maximum).
- Alternatively, if `Interpolate=true` we interpolate the data onto a new grid that has dimensions `dims`. This can be useful to compare data sets that are originally given in different resolutions.

# 3D Example with no interpolation:
```julia-repl
julia> Lon,Lat,Depth   =   LonLatDepthGrid(10:20,30:40,(-300:25:0)km);
julia> Data            =   Depth*2;                # some data
julia> Vx,Vy,Vz        =   ustrip(Data*3),ustrip(Data*4),ustrip(Data*5);
julia> Data_set3D      =   GeoData(Lon,Lat,Depth,(Depthdata=Data,LonData=Lon, Velocity=(Vx,Vy,Vz)))
GeoData 
  size  : (11, 11, 13)
  lon   ϵ [ 10.0 : 20.0]
  lat   ϵ [ 30.0 : 40.0]
  depth ϵ [ -300.0 km : 0.0 km]
  fields: (:Depthdata, :LonData, :Velocity)
julia> Data_extracted = ExtractSubvolume(Data_set3D,Lon_level=(10,12),Lat_level=(35,40))
GeoData 
  size  : (3, 6, 13)
  lon   ϵ [ 10.0 : 12.0]
  lat   ϵ [ 35.0 : 40.0]
  depth ϵ [ -300.0 km : 0.0 km]
  fields: (:Depthdata, :LonData, :Velocity)
```
By default it extracts the data points closest to the area defined by Lon_level/Lat_level/Depth_level.

# 3D Example with interpolation:
Alternatively, you can also interpolate the data onto a new grid:
```julia
julia> Data_extracted = ExtractSubvolume(Data_set3D,Lon_level=(10,12),Lat_level=(35,40), Interpolate=true, dims=(50,51,52))
GeoData 
  size  : (50, 51, 52)
  lon   ϵ [ 10.0 : 12.0]
  lat   ϵ [ 35.0 : 40.0]
  depth ϵ [ -300.0 km : 0.0 km]
  fields: (:Depthdata, :LonData, :Velocity)
```

"""
function ExtractSubvolume(V::GeoData; Interpolate=false, Lon_level=nothing, Lat_level=nothing, Depth_level=nothing, dims=(50,50,50))

    if isnothing(Lon_level)
        Lon_level = (minimum(V.lon.val), maximum(V.lon.val))
    end
    if isnothing(Lat_level)
        Lat_level = (minimum(V.lat.val), maximum(V.lat.val))
    end
    if isnothing(Depth_level)
        Depth_level = (minimum(V.depth.val), maximum(V.depth.val))
    end
    if Interpolate
        Lon,Lat,Depth   = LonLatDepthGrid(  LinRange(Lon_level[1],      Lon_level[2],   dims[1]),
                                            LinRange(Lat_level[1],      Lat_level[2],   dims[2]),
                                            LinRange(Depth_level[1],    Depth_level[2], dims[3]) );
        Data_extract    =   InterpolateDataFields(V, Lon, Lat, Depth)

    else
        # Don't interpolate
        i_s, i_e    =   argmin(abs.(V.lon.val[:,1,1] .- Lon_level[1])), argmin(abs.(V.lon.val[:,1,1] .- Lon_level[2]))
        iLon        =   i_s:i_e;
        
        i_s, i_e    =   argmin(abs.(V.lat.val[1,:,1] .- Lat_level[1])), argmin(abs.(V.lat.val[1,:,1] .- Lat_level[2]))
        iLat        =   i_s:i_e;
        
        i_s, i_e    =   argmin(abs.(V.depth.val[1,1,:] .- ustrip(Depth_level[1]))), argmin(abs.(V.depth.val[1,1,:] .- ustrip(Depth_level[2])))
        step        =   1;
        if i_e<i_s
            step=-1
        end
        iDepth      =   i_s:step:i_e;
        Data_extract =  ExtractDataSets(V, iLon, iLat, iDepth);
    end

    return Data_extract
end


function CheckBounds(Data::GeoUnit, Data_Cross)
    
    min_Data, max_Data = NumValue(minimum(Data.val)), NumValue(maximum(Data.val));
    if ustrip(Data_Cross) < min_Data || ustrip(Data_Cross)>max_Data
        error("Outside bounds [$min_Data : $max_Data]; $Data_Cross")
    end
end

function CheckBounds(Data::AbstractArray, Data_Cross)
    
    min_Data, max_Data = NumValue(minimum(Data)), NumValue(maximum(Data));
    if ustrip(Data_Cross) < min_Data || ustrip(Data_Cross)>max_Data
        error("Outside bounds [$min_Data : $max_Data]; $Data_Cross")
    end
end

# CHECKS FOR VOLUME, SURFACE OR POINTS
function CheckDataSet(DataSet::GeoData)
    if length(size(DataSet.lon)) == 1 # scattered points
        return 1
    else 
        if any(size(DataSet.lon).==1) # surface data
            return 2
        else # volume data
            return 3
        end
    end
end

function CheckDataSet(DataSet::CartData)
    if length(size(DataSet.x)) == 1 # scattered points
        return 1
    else 
        if any(size(DataSet.x).==1) # surface data
            return 2
        else # volume data
            return 3
        end
    end
end


"""
    InterpolateDataFields(V::AbstractGeneralGrid, Lon, Lat, Depth)

Interpolates a data field `V` on a grid defined by `Lon,Lat,Depth`

# Example
```julia
julia> x        =   0:2:10
julia> y        =   -5:5
julia> z        =   -10:2:2
julia> X,Y,Z    =   XYZGrid(x, y, z);
julia> Data     =   Z
julia> Data_set1=   CartData(X,Y,Z, (FakeData=Data,Data2=Data.+1.))
CartData 
    size    : (6, 11, 7)
    x       ϵ [ 0.0 km : 10.0 km]
    y       ϵ [ -5.0 km : 5.0 km]
    z       ϵ [ -10.0 km : 2.0 km]
    fields  : (:FakeData, :Data2)
  attributes: ["note"]
  
julia> X,Y,Z    =   XYZGrid(0:4:10, -1:.1:1, -5:.1:1 );
julia> Data_set2= InterpolateDataFields(Data_set1, X,Y,Z)
```

"""
function InterpolateDataFields(V::AbstractGeneralGrid, Lon, Lat, Depth)

    X,Y,Z = coordinate_grids(V)

    Lon_vec     =  X[:,1,1];
    Lat_vec     =  Y[1,:,1];
    Depth_vec   =  Z[1,1,:];
    if Depth_vec[1]>Depth_vec[end]
        ReverseData = true
    else
        ReverseData = false
    end

    fields_new  = V.fields;
    field_names = keys(fields_new);
    for i = 1:length(V.fields)
        if typeof(V.fields[i]) <: Tuple
            # vector or anything that contains more than 1 field
            data_tuple = fields_new[i]      # we have a tuple (likely a vector field), so we have to loop 
            data_array = zeros(size(Lon,1),size(Lon,2),size(Lon,3),length(data_tuple));     # create a 3D array that holds the 2D interpolated values
            unit_array = zeros(size(data_array));

            for j=1:length(data_tuple)
                if ReverseData
                    ndim        =   length(size(data_tuple[j]))
                    interpol    =   linear_interpolation((Lon_vec, Lat_vec, reverse(Depth_vec)), reverse(ustrip.(data_tuple[j]), dims=ndim) ,extrapolation_bc = Flat());      # create interpolation object
                else
                    interpol    =   linear_interpolation((Lon_vec, Lat_vec, Depth_vec), ustrip.(data_tuple[j]),extrapolation_bc = Flat());      # create interpolation object
                end
                data_array[:,:,:,j] =   interpol.(Lon, Lat, ustrip.(Depth));          
            end
            data_new    = tuple([data_array[:,:,:,c] for c in 1:size(data_array,4)]...)     # transform 3D matrix to tuple

        else
            # scalar field
            if ReverseData
                ndim        =   length(size(V.fields[i]))
                interpol    =   linear_interpolation((Lon_vec, Lat_vec, reverse(Depth_vec)), reverse(V.fields[i], dims=ndim), extrapolation_bc = Flat(),);            # create interpolation object
            else
                interpol    =   linear_interpolation((Lon_vec, Lat_vec, Depth_vec), V.fields[i], extrapolation_bc = Flat());            # create interpolation object
            end
            data_new    =   interpol.(Lon, Lat, ustrip.(Depth));                                                 # interpolate data field
        end
        
        # replace the one 
        new_field   =   NamedTuple{(field_names[i],)}((data_new,))                          # Create a tuple with same name
        fields_new  =   merge(fields_new, new_field);                                       # replace the field in fields_new
        
    end
    

    # Create a GeoData struct with the newly interpolated fields
    if isa(V,GeoData)
        Data_profile = GeoData(Lon, Lat, Depth, fields_new);
    elseif isa(V,CartData)
        Data_profile = CartData(Lon, Lat, Depth, fields_new);
    else
        error("still to be implemented")
    end

    return Data_profile
end

"""
    InterpolateDataFields(V::UTMData, EW, NS, Depth)

Interpolates a data field `V` on a grid defined by `UTM,Depth`
"""
function InterpolateDataFields(V::UTMData, EW, NS, Depth)

    EW_vec      =  V.EW.val[:,1,1];
    NS_vec      =  V.NS.val[1,:,1];
    Depth_vec   =  V.depth.val[1,1,:];
    if Depth_vec[1]>Depth_vec[end]
        ReverseData = true
    else
        ReverseData = false
    end

    fields_new  = V.fields;
    field_names = keys(fields_new);
    for i = 1:length(V.fields)
        if typeof(V.fields[i]) <: Tuple
            # vector or anything that contains more than 1 field
            data_tuple = fields_new[i]      # we have a tuple (likely a vector field), so we have to loop 
            data_array = zeros(size(EW,1),size(EW,2),size(EW,3),length(data_tuple));     # create a 3D array that holds the 2D interpolated values
            unit_array = zeros(size(data_array));

            for j=1:length(data_tuple)
                if ReverseData
                    ndim        =   length(size(data_tuple[j]))
                    interpol    =   linear_interpolation((EW_vec, NS_vec, reverse(Depth_vec)), reverse(ustrip.(data_tuple[j]), dims=ndim) ,extrapolation_bc = Flat());      # create interpolation object
                else
                    interpol    =   linear_interpolation((EW_vec, NS_vec, Depth_vec), ustrip.(data_tuple[j]),extrapolation_bc = Flat());      # create interpolation object
                end
                data_array[:,:,:,j] =   interpol.(EW, NS, Depth);          
            end
            data_new    = tuple([data_array[:,:,:,c] for c in 1:size(data_array,4)]...)     # transform 3D matrix to tuple

        else
            # scalar field
            if ReverseData
                ndim        =   length(size(V.fields[i]))
                interpol    =   linear_interpolation((EW_vec, NS_vec, reverse(Depth_vec)), reverse(V.fields[i], dims=ndim), extrapolation_bc = Flat(),);            # create interpolation object
            else
                interpol    =   linear_interpolation((EW_vec, NS_vec, Depth_vec), V.fields[i], extrapolation_bc = Flat());            # create interpolation object
            end
            data_new    =   interpol.(EW, NS, Depth);                                                 # interpolate data field
        end
        
        # replace the one 
        new_field   =   NamedTuple{(field_names[i],)}((data_new,))                          # Create a tuple with same name
        fields_new  =   merge(fields_new, new_field);                                       # replace the field in fields_new
        
    end
    

    # Create a GeoData struct with the newly interpolated fields
    Data_profile = UTMData(EW, NS, Depth, fields_new);

    return Data_profile
end

"""
    InterpolateDataFields2D(V::GeoData, Lon, Lat)

Interpolates a data field `V` on a 2D grid defined by `Lon,Lat`. Typically used for horizontal surfaces
"""
function InterpolateDataFields2D(V::GeoData, Lon, Lat)

    Lon_vec     =  V.lon.val[:,1,1];
    Lat_vec     =  V.lat.val[1,:,1];
   
    fields_new  = V.fields;
    field_names = keys(fields_new);
    for i = 1:length(V.fields)
        if typeof(V.fields[i]) <: Tuple
            # vector or anything that contains more than 1 field
            data_tuple = fields_new[i]      # we have a tuple (likely a vector field), so we have to loop 
            data_array = zeros(size(Lon,1),size(Lon,2),size(Lon,3),length(data_tuple));     # create a 3D array that holds the 2D interpolated values
            unit_array = zeros(size(data_array));

            for j=1:length(data_tuple)
                if length(size(data_tuple[j]))==3
                    interpol    =   linear_interpolation((Lon_vec, Lat_vec), ustrip.(data_tuple[j][:,:,1]),extrapolation_bc = Flat());      # create interpolation object
                else
                    interpol    =   linear_interpolation((Lon_vec, Lat_vec), ustrip.(data_tuple[j]),extrapolation_bc = Flat());      # create interpolation object
                end
                data_array[:,:,1,j] =   interpol.(Lon, Lat);          
            end
            if length(size(data_tuple[1]))==3
                data_new    = tuple([data_array[:,:,:,c] for c in 1:size(data_array,4)]...)     # transform 3D matrix to tuple
            else
                data_new    = tuple([data_array[:,:,1,c] for c in 1:size(data_array,4)]...)     # transform 3D matrix to tuple
            end
        else
            # scalar field
            if length(size(V.fields[i]))==3
                interpol    =   linear_interpolation((Lon_vec, Lat_vec), V.fields[i][:,:,1], extrapolation_bc = Flat());            # create interpolation object
            else
                interpol    =   linear_interpolation((Lon_vec, Lat_vec), V.fields[i], extrapolation_bc = Flat());            # create interpolation object
            end

            data_new    =   interpol.(Lon, Lat);                                                 # interpolate data field
        end
        
        # replace the one 
        new_field   =   NamedTuple{(field_names[i],)}((data_new,))                          # Create a tuple with same name
        fields_new  =   merge(fields_new, new_field);                                       # replace the field in fields_new
        
    end

    # Interpolate z-coordinate as well
    if length(size(V.lon))==3
        interpol    =   linear_interpolation((Lon_vec, Lat_vec), V.depth.val[:,:,1], extrapolation_bc = Flat());            # create interpolation object
    else
        interpol    =   linear_interpolation((Lon_vec, Lat_vec), V.depth.val, extrapolation_bc = Flat());            # create interpolation object
    end
    depth_new =  interpol.(Lon, Lat);    
    

    # Create a GeoData struct with the newly interpolated fields
    # Data_profile = GeoData(Lon, Lat, Depth*0, fields_new);

    return depth_new, fields_new
end

"""
    InterpolateDataFields2D(V::UTMData, EW, NS)

Interpolates a data field `V` on a 2D grid defined by `UTM`. Typically used for horizontal surfaces
"""
function InterpolateDataFields2D(V::UTMData, EW, NS)

    EW_vec      =  V.EW.val[:,1,1];
    NS_vec      =  V.NS.val[1,:,1];
   
    fields_new  = V.fields;
    field_names = keys(fields_new);
    for i = 1:length(V.fields)
        if typeof(V.fields[i]) <: Tuple
            # vector or anything that contains more than 1 field
            data_tuple = fields_new[i]      # we have a tuple (likely a vector field), so we have to loop 
            data_array = zeros(size(EW,1),size(EW,2),size(EW,3),length(data_tuple));     # create a 3D array that holds the 2D interpolated values
            unit_array = zeros(size(data_array));

            for j=1:length(data_tuple)
                interpol    =   linear_interpolation((EW_vec, NS_vec), ustrip.(data_tuple[j]),extrapolation_bc = Flat());      # create interpolation object
                data_array[:,:,1,j] =   interpol.(EW, NS);          
            end
            data_new    = tuple([data_array[:,:,1,c] for c in 1:size(data_array,4)]...)     # transform 3D matrix to tuple

        else
            # scalar field
            if length(size(V.fields[i]))==3
                interpol    =   linear_interpolation((EW_vec, NS_vec), V.fields[i][:,:,1], extrapolation_bc = Flat());            # create interpolation object
            else
                interpol    =   linear_interpolation((EW_vec, NS_vec), V.fields[i], extrapolation_bc = Flat());            # create interpolation object
            end

            data_new    =   interpol.(EW, NS);                                                 # interpolate data field
        end
        
        # replace the one 
        new_field   =   NamedTuple{(field_names[i],)}((data_new,))                          # Create a tuple with same name
        fields_new  =   merge(fields_new, new_field);                                       # replace the field in fields_new
        
    end

    # Interpolate z-coordinate as well
    if length(size(V.depth))==3
        interpol    =   linear_interpolation((EW_vec, NS_vec), V.depth.val[:,:,1], extrapolation_bc = Flat());            # create interpolation object
    else
        interpol    =   linear_interpolation((EW_vec, NS_vec), V.depth.val, extrapolation_bc = Flat());            # create interpolation object
    end
    depth_new =  interpol.(EW, NS);    
    

    # Create a UTMData struct with the newly interpolated fields
    # Data_profile = UTMData(EW, NS, Depth*0, fields_new);

    return depth_new, fields_new
end


"""
    Surf_interp = InterpolateDataOnSurface(V::ParaviewData, Surf::ParaviewData)

Interpolates a 3D data set `V` on a surface defined by `Surf`. nex
# Example
```julia
julia> Data
ParaviewData 
  size  : (33, 33, 33)
  x     ϵ [ -3.0 : 3.0]
  y     ϵ [ -2.0 : 2.0]
  z     ϵ [ -2.0 : 0.0]
  fields: (:phase, :density, :visc_total, :visc_creep, :velocity, :pressure, :temperature, :dev_stress, :strain_rate, :j2_dev_stress, :j2_strain_rate, :plast_strain, :plast_dissip, :tot_displ, :yield, :moment_res, :cont_res)
julia> surf
ParaviewData 
  size  : (96, 96, 1)
  x     ϵ [ -2.9671875 : 3.2671875]
  y     ϵ [ -1.9791666666666667 : 1.9791666666666667]
  z     ϵ [ -1.5353766679763794 : -0.69925457239151]
  fields: (:Depth,)
julia> Surf_interp = InterpolateDataOnSurface(Data, surf)
  ParaviewData 
    size  : (96, 96, 1)
    x     ϵ [ -2.9671875 : 3.2671875]
    y     ϵ [ -1.9791666666666667 : 1.9791666666666667]
    z     ϵ [ -1.5353766679763794 : -0.69925457239151]
    fields: (:phase, :density, :visc_total, :visc_creep, :velocity, :pressure, :temperature, :dev_stress, :strain_rate, :j2_dev_stress, :j2_strain_rate, :plast_strain, :plast_dissip, :tot_displ, :yield, :moment_res, :cont_res)
```
"""
function InterpolateDataOnSurface(V::ParaviewData, Surf::ParaviewData)
    
    # Create GeoData structure:
    V_geo               =   GeoData(V.x.val, V.y.val, V.z.val, V.fields)
    V_geo.depth.val     =   ustrip(V_geo.depth.val);

    Surf_geo            =   GeoData(Surf.x.val, Surf.y.val, Surf.z.val, Surf.fields)
    Surf_geo.depth.val  =   ustrip(Surf_geo.depth.val);

    Surf_interp_geo     =   InterpolateDataOnSurface(V_geo, Surf_geo)
    Surf_interp         =   ParaviewData(Surf_interp_geo.lon.val, Surf_interp_geo.lat.val, ustrip.(Surf_interp_geo.depth.val), Surf_interp_geo.fields)

    return Surf_interp

end


"""
    Surf_interp = InterpolateDataOnSurface(V::GeoData, Surf::GeoData)

Interpolates a 3D data set `V` on a surface defined by `Surf`
"""
function InterpolateDataOnSurface(V::GeoData, Surf::GeoData)
    
    Surf_interp = InterpolateDataFields(V, Surf.lon.val, Surf.lat.val, Surf.depth.val)

    return Surf_interp
end



# Extracts a sub-data set using indices
function ExtractDataSets(V::AbstractGeneralGrid, iLon, iLat, iDepth)

    X,Y,Z = coordinate_grids(V)


    Lon     =   zeros(typeof(X[1]), length(iLon),length(iLat),length(iDepth));
    Lat     =   zeros(typeof(Y[1]), length(iLon),length(iLat),length(iDepth));
    Depth   =   zeros(typeof(Z[1]), length(iLon),length(iLat),length(iDepth));
    
    iLo                 =   1:length(iLon);
    iLa                 =   1:length(iLat);
    iDe                 =   1:length(iDepth)
    Lon[iLo,iLa,iDe]    =   X[iLon, iLat, iDepth];
    Lat[iLo,iLa,iDe]    =   Y[iLon, iLat, iDepth];
    Depth[iLo,iLa,iDe]  =   Z[iLon, iLat, iDepth];

    fields_new  = V.fields;
    field_names = keys(fields_new);
    for i = 1:length(V.fields)
        if typeof(V.fields[i]) <: Tuple
            # vector or anything that contains more than 1 field
            data_tuple = fields_new[i]      # we have a tuple (likely a vector field), so we have to loop 
            data_array = zeros(typeof(data_tuple[1][1]),length(iLon),length(iLat),length(iDepth),length(data_tuple));     # create a 3D array that holds the 2D interpolated values
            unit_array = zeros(size(data_array));

            for j=1:length(data_tuple)
                data_field           =   data_tuple[j];
                data_array[:,:,:,j]  =   data_field[iLon, iLat, iDepth];          
            end
            data_new    = tuple([data_array[:,:,:,c] for c in 1:size(data_array,4)]...)       # transform 4D matrix to tuple

        else
            # scalar field
            data_new                =   zeros(typeof(V.fields[i][1]), length(iLon),length(iLat),length(iDepth));
            data_new[iLo,iLa,iDe]   =   V.fields[i][iLon, iLat, iDepth]                                 # interpolate data field
        end
        
        # replace the one 
        new_field   =   NamedTuple{(field_names[i],)}((data_new,))                          # Create a tuple with same name
        fields_new  =   merge(fields_new, new_field);                                       # replace the field in fields_new
        
    end
    

    # Create a GeoData struct with the newly interpolated fields
    if isa(V,GeoData)
        Data_profile = GeoData(Lon, Lat, Depth, fields_new);
    elseif isa(V,CartData)
        Data_profile = CartData(Lon, Lat, Depth, fields_new);
    else
        error("Not yet implemented")
    end

end

"""
    V_sub = SubtractHorizontalMean(V::AbstractArray{T, 3}; Percentage=false)

Subtracts the horizontal average of the 3D data array V.

If `Percentage=true`, the result is given as percentage; otherwise absolute values are returned

"""
function SubtractHorizontalMean(V::AbstractArray{T, 3}; Percentage=false) where T

    nx        = size(V,1);
    ny        = size(V,2);
    NumLayers = size(V,3); # get the number of depth levels

    if Percentage
        V_sub     = zeros(size(V));                 # no units
    else
        V_sub     = zeros(typeof(V[1]), size(V));   
    end

    for iLayer = 1:NumLayers
        average             =   mean(filter(!isnan, vec(V[:,:,iLayer])));
        
        if Percentage
            V_sub[:,:,iLayer]   =   ustrip(V[:,:,iLayer]) .- ustrip(average);
            V_sub[:,:,iLayer]   =   V_sub[:,:,iLayer]./ustrip(average)*100.0;     # the result is normalized 
        else
            V_sub[:,:,iLayer]   =   V[:,:,iLayer] .- average;
        end
    end

    return V_sub
end

"""
    V_sub = SubtractHorizontalMean(V::AbstractArray{T, 2}; Percentage=false)

Subtracts the horizontal average of the 2D data array V.

If `Percentage=true`, the result is given as percentage; otherwise absolute values are returned

"""
function SubtractHorizontalMean(V::AbstractArray{T, 2}; Percentage=false) where T

    nx        = size(V,1);
    NumLayers = size(V,2); # get the number of depth levels

    if Percentage
        V_sub     = zeros(size(V));                 # no units
    else
        V_sub     = zeros(typeof(V[1]), size(V));   
    end

    for iLayer = 1:NumLayers
        average             =   mean(filter(!isnan, vec(V[:,iLayer])));
        
        if Percentage
            V_sub[:,iLayer]   =   ustrip(V[:,iLayer]) .- ustrip(average);
            V_sub[:,iLayer]   =   V_sub[:,iLayer]./ustrip(average)*100.0;     # the result is normalized 
        else
            V_sub[:,iLayer]   =   V[:,iLayer] .- average;
        end
    end

    return V_sub
end





""" 
    ParseColumns_CSV_File(data_file, num_columns)

This parses numbers from CSV file that is read in with `CSV.File`.
That is useful in case the CSV files has tables that contain both strings (e.g., station names) and numbers (lat/lon/height) and you are only intested in the numbers


# Example
This example assumes that the data starts at line 18, that the colums are separated by spaces, and that it contains at most 4 columns with data:
```julia-repl
julia> using CSV
julia> data_file        =   CSV.File("FileName.txt",datarow=18,header=false,delim=' ')
julia> data = ParseColumns_CSV_File(data_file, 4)
```

"""
function ParseColumns_CSV_File(data_file, num_columns)
    data                =   zeros(size(data_file,1), num_columns);    
    for (row_num,row) in enumerate(data_file)
        num         =   0;
        for i=1:length(row)
            if typeof(row[i])==Float64
                num          +=  1;
                data[row_num,num] = row[i]
            else
            
                try parse(Float64,row[i])
                    num          +=  1;
                    data[row_num,num] = parse(Float64,row[i])
                catch
                end
            end

        end
    end
    return data
end


""" 
    AboveSurface(Data::GeoData, DataSurface::GeoData; above=true)

Returns a boolean array of size(Data.Lon), which is true for points that are above the surface DataSurface (or for points below if above=false).

This can be used, for example, to mask points above/below the Moho in a volumetric dataset or in a profile.

# Example
First we create a 3D data set and a 2D surface:
```julia
julia> Lon,Lat,Depth   =   LonLatDepthGrid(10:20,30:40,(-300:25:0)km);
julia> Data            =   Depth*2; 
julia> Data_set3D      =   GeoData(Lon,Lat,Depth,(Depthdata=Data,LonData=Lon))
GeoData 
  size  : (11, 11, 13)
  lon   ϵ [ 10.0 : 20.0]
  lat   ϵ [ 30.0 : 40.0]
  depth ϵ [ -300.0 km : 0.0 km]
  fields: (:Depthdata, :LonData)
julia> Lon,Lat,Depth   =   LonLatDepthGrid(10:20,30:40,-40km);  
julia> Data_Moho       =   GeoData(Lon,Lat,Depth+Lon*km, (MohoDepth=Depth,))
  GeoData 
    size  : (11, 11, 1)
    lon   ϵ [ 10.0 : 20.0]
    lat   ϵ [ 30.0 : 40.0]
    depth ϵ [ -30.0 km : -20.0 km]
    fields: (:MohoDepth,)
```
Next, we intersect the surface with the data set:
```julia
julia> Above       =   AboveSurface(Data_set3D, Data_Moho); 
```
Now, `Above` is a boolean array that is true for points above the surface and false for points below and at the surface.

"""
function AboveSurface(Data::GeoData, DataSurface::GeoData; above=true)
    
    if size(DataSurface.lon)[3]!=1
        error("It seems that DataSurface is not a surface")
    end

    # Create interpolation object for surface
    Lon_vec     =  DataSurface.lon.val[:,1,1];
    Lat_vec     =  DataSurface.lat.val[1,:,1];
    interpol    =  linear_interpolation((Lon_vec, Lat_vec), ustrip.(DataSurface.depth.val[:,:,1]));            # create interpolation object

    DepthSurface = interpol.(Data.lon.val,Data.lat.val);
    DepthSurface = DepthSurface*unit(DataSurface.depth.val[1])

    if above
        Above       =   Data.depth.val .> DepthSurface;
    else
        Above       =   Data.depth.val .< DepthSurface;
    end

    return Above
end

"""
    Below = BelowSurface(Data::GeoData, DataSurface::GeoData)

Determines if points within the 3D `Data` structure are below the GeoData surface `DataSurface`
"""
function BelowSurface(Data::GeoData, DataSurface::GeoData)
    return AboveSurface(Data::GeoData, DataSurface::GeoData; above=false)
end

"""
    Above = AboveSurface(Data_Cart::ParaviewData, DataSurface_Cart::ParaviewData; above=true)

Determines if points within the 3D `Data_Cart` structure are above the Cartesian surface `DataSurface_Cart`
"""
function AboveSurface(Data_Cart::ParaviewData, DataSurface_Cart::ParaviewData; above=true)

    Data            =   GeoData(ustrip.(Data_Cart.x.val),       ustrip.(Data_Cart.y.val),        ustrip.(Data_Cart.z.val), Data_Cart.fields)
    DataSurface     =   GeoData(ustrip.(DataSurface_Cart.x.val),ustrip.(DataSurface_Cart.y.val), ustrip.(DataSurface_Cart.z.val), DataSurface_Cart.fields )

    return Above    =   AboveSurface(Data, DataSurface; above=above)
end

"""
    Above = AboveSurface(Data_Cart::CartData, DataSurface_Cart::CartData; above=true)

Determines if points within the 3D `Data_Cart` structure are above the Cartesian surface `DataSurface_Cart`
"""
function AboveSurface(Data_Cart::CartData, DataSurface_Cart::CartData; above=true)

    Data            =   GeoData(ustrip.(Data_Cart.x.val),       ustrip.(Data_Cart.y.val),        ustrip.(Data_Cart.z.val), Data_Cart.fields)
    DataSurface     =   GeoData(ustrip.(DataSurface_Cart.x.val),ustrip.(DataSurface_Cart.y.val), ustrip.(DataSurface_Cart.z.val), DataSurface_Cart.fields )

    return Above    =   AboveSurface(Data, DataSurface; above=above)
end

"""
    Above = AboveSurface(Grid::CartGrid, DataSurface_Cart::CartData; above=true)

Determines if points described by the `Grid` CartGrid structure are above the Cartesian surface `DataSurface_Cart`
"""
function AboveSurface(Grid::CartGrid, DataSurface_Cart::CartData; above=true)

    X,Y,Z = XYZGrid(Grid.coord1D...)
    Data = CartData(Grid,(Z=Z,))

    return AboveSurface(Data, DataSurface_Cart; above=above)
end


"""
    Below = BelowSurface(Grid::CartGrid, DataSurface_Cart::CartData)

    Determines if points described by the `Grid` CartGrid structure are above the Cartesian surface `DataSurface_Cart`
"""
function BelowSurface(Grid::CartGrid, DataSurface_Cart::CartData)
    return AboveSurface(Grid, DataSurface_Cart; above=false)
end


"""
    Below = BelowSurface(Data_Cart::ParaviewData, DataSurface_Cart::ParaviewData)

Determines if points within the 3D Data_Cart structure are below the Cartesian surface DataSurface_Cart
"""
function BelowSurface(Data_Cart::ParaviewData, DataSurface_Cart::ParaviewData)
    return AboveSurface(Data_Cart::ParaviewData, DataSurface_Cart::ParaviewData; above=false)
end

"""
    Below = BelowSurface(Data_Cart::CartData, DataSurface_Cart::CartData)

Determines if points within the 3D Data_Cart structure are below the Cartesian surface DataSurface_Cart
"""
function BelowSurface(Data_Cart::CartData, DataSurface_Cart::CartData)
    return AboveSurface(Data_Cart::CartData, DataSurface_Cart::CartData; above=false)
end


"""
    VoteMap(DataSets::Vector{GeoData}, criteria::Vector{String}, dims=(50,50,50))

Creates a Vote map which shows consistent features in different 2D/3D tomographic datasets.

The way it works is:
- define whether VoteMaps should be created using only overlapping regions, the maximum extent of all tomographies or in a costom range:
    -> 'overlapping', 'maximum' or a Dictionary with entries 'lon','lat','depth'
- Interpolate the fields of all DataSets to common coordinates

- Filter data points in one model (e.g., areas with a velocity anomaly > 2 percent). Set everything that satisfies this criteria to 1 and everything else to 0.
- Sum the results of the different datasets

If a feature is consistent between different datasets, it will have larger values. 

# Example
We assume that we have 2 seismic velocity datasets `Data_Zhao_Pwave` and `DataKoulakov_Alps`:
```julia
julia> Data_Zhao_Pwave
GeoData 
  size  : (121, 94, 101)
  lon   ϵ [ 0.0 : 18.0]
  lat   ϵ [ 38.0 : 51.95]
  depth ϵ [ -1001.0 km : -1.0 km]
  fields: (:dVp_Percentage,)
julia> DataKoulakov_Alps
  GeoData 
    size  : (108, 81, 35)
    lon   ϵ [ 4.0 : 20.049999999999997]
    lat   ϵ [ 37.035928143712574 : 49.01197604790419]
    depth ϵ [ -700.0 km : -10.0 km]
    fields: (:dVp_percentage, :dVs_percentage)
```
You can create a VoteMap which combines the two data sets with:
```julia 
julia> Data_VoteMap = VoteMap([Data_Zhao_Pwave,DataKoulakov_Alps],["dVp_Percentage>2.5","dVp_percentage>3.0"])
GeoData 
  size  : (50, 50, 50)
  lon   ϵ [ 4.0 : 18.0]
  lat   ϵ [ 38.0 : 49.01197604790419]
  depth ϵ [ -700.0 km : -10.0 km]
  fields: (:VoteMap,)
```

You can also create a VoteMap of a single dataset:
```julia 
julia> Data_VoteMap = VoteMap(Data_Zhao_Pwave,"dVp_Percentage>2.5", dims=(50,51,52))
GeoData 
  size  : (50, 51, 52)
  lon   ϵ [ 0.0 : 18.0]
  lat   ϵ [ 38.0 : 51.95]
  depth ϵ [ -1001.0 km : -1.0 km]
  fields: (:VoteMap,)
```

"""
function VoteMap(DataSets::Vector{GeoData}, criteria::Vector{String}; dims=(50,50,50))

    numDataSets = length(DataSets)

    if length(criteria) != numDataSets
        error("Need the same number of criteria as the number of data sets")
    end
    
    # Determine the overlapping lon/lat/depth regions of all datasets
    lon_limits  = [minimum(DataSets[1].lon.val);        maximum(DataSets[1].lon.val)];
    lat_limits  = [minimum(DataSets[1].lat.val);        maximum(DataSets[1].lat.val)];
    z_limits    = [minimum(DataSets[1].depth.val);      maximum(DataSets[1].depth.val)];
    for i=1:numDataSets
        lon_limits[1]   =   maximum([lon_limits[1]  minimum(DataSets[i].lon.val)]);
        lon_limits[2]   =   minimum([lon_limits[2]  maximum(DataSets[i].lon.val)]);

        lat_limits[1]   =   maximum([lat_limits[1]  minimum(DataSets[i].lat.val)]);
        lat_limits[2]   =   minimum([lat_limits[2]  maximum(DataSets[i].lat.val)]);
 
        z_limits[1]     =   maximum([z_limits[1]    minimum(DataSets[i].depth.val)]);
        z_limits[2]     =   minimum([z_limits[2]    maximum(DataSets[i].depth.val)]);
    end

    # Loop over all datasets, and interpolate the data set to the new (usually smaller) domain
    VoteMap             =   zeros(Int64,dims)
    for i=1:numDataSets
        VoteMap_Local   =   zeros(Int64,dims)
        
        # Interpolate data set to smaller domain
        DataSet         =   ExtractSubvolume(DataSets[i]; Interpolate=true, Lon_level=lon_limits, Lat_level=lat_limits, Depth_level=z_limits, dims=dims);

        # Extract the criteria to evaluate
        expr            =   Meta.parse(criteria[i]);     # the expression, such as Vs>1.0

        # Extract data field
        if !haskey(DataSet.fields,expr.args[2])
            error("The GeoData set does not have the field: $(expr.args[2])")
        end

        Array3D         =   ustrip.(DataSet.fields[expr.args[2]]);                  # strip units, just in case
        
        # Modify the value, to be Array3D 
        expr_mod        =   Expr(:call, expr.args[1], :($Array3D), expr.args[3]);      # modify the original expression to use Array3D as variable name
        
        # The expression should have a ".", such as Array .> 1.0. If not, it will not apply this in a pointwise manner
        #   Here, we add this dot if it is not there yet
        if cmp(String(expr_mod.args[1])[1],Char('.'))==1
            expr_mod.args[1] = Symbol(".",expr_mod.args[1]);
        end

        ind                 = eval(expr_mod);    # evaluate the modified expression
        VoteMap_Local[ind] .= 1;                 # assign vote-map

        VoteMap = VoteMap + VoteMap_Local;       # Sum 
    end

    DataSet     =   ExtractSubvolume(DataSets[1], Interpolate=true, Lon_level=lon_limits, Lat_level=lat_limits, Depth_level=z_limits, dims=dims);

    # Construct GeoData set that holds the VoteMap (makes it easier to write paraview files)
    VoteData    =   GeoData(DataSet.lon.val,DataSet.lat.val,DataSet.depth.val, (VoteMap=VoteMap,));

    return VoteData
end

# Make this work for single data sets as well
function VoteMap(DataSets::GeoData, criteria::String; dims=(50,50,50))
    VoteMap([DataSets], [criteria]; dims=dims)
end


"""
This is a modified vote map algorithm provided by E. Kaestle 
A more detailed help will follow

Example: 
```julia
julia> Pwave_Zhao = load("./Zhao2016/Zhao_Pwave.jld2","Data_set_Zhao2016_Vp")
julia> Pwave_Paffrath = load("./Paffrath2021/Paffrath2021.jld2","Data_set")
julia> Pwave_Rappisi  = load("./Rappisi2022/Rappisi2022.jld2","Data_set")
julia > Data_VoteMap = VoteMapNew( [Pwave_Paffrath, Pwave_Zhao,Pwave_Rappisi],
                        ["dVp_perc","dVp_Percentage","dVp_perc"], dims=(100,100,100),
                        threshold_stadev=1.5,meancorrection=true,modelsize="maximum",votes="relative",mindepth=100.)


```

"""

function VoteMapKaestle(DataSets::Vector{GeoData}, elements::Vector{String};
    dims=(50,50,50), threshold_stadev=1.0, meancorrection=true,
    modelsize="overlapping",votes="absolute",mindepth=0.)

    numDataSets = length(DataSets)

    if length(elements) != numDataSets
        error("Need the same number of elements as the number of data sets")
    end
    
    # Determine the available lon/lat/depth regions of all datasets
    lon_limits  = [minimum(DataSets[1].lon.val);        maximum(DataSets[1].lon.val)];
    lat_limits  = [minimum(DataSets[1].lat.val);        maximum(DataSets[1].lat.val)];
    z_limits    = [minimum(DataSets[1].depth.val);      maximum(DataSets[1].depth.val)];
    if modelsize == "overlapping"
        for i=1:numDataSets
            lon_limits[1]   =   maximum([lon_limits[1]  minimum(DataSets[i].lon.val)]);
            lon_limits[2]   =   minimum([lon_limits[2]  maximum(DataSets[i].lon.val)]);
    
            lat_limits[1]   =   maximum([lat_limits[1]  minimum(DataSets[i].lat.val)]);
            lat_limits[2]   =   minimum([lat_limits[2]  maximum(DataSets[i].lat.val)]);
     
            z_limits[1]     =   maximum([z_limits[1]    minimum(DataSets[i].depth.val)]);
            z_limits[2]     =   minimum([z_limits[2]    maximum(DataSets[i].depth.val)]);
        end
    elseif modelsize == "maximum"
        for i=1:numDataSets
            lon_limits[1]   =   minimum([lon_limits[1]  minimum(DataSets[i].lon.val)]);
            lon_limits[2]   =   maximum([lon_limits[2]  maximum(DataSets[i].lon.val)]);

            lat_limits[1]   =   minimum([lat_limits[1]  minimum(DataSets[i].lat.val)]);
            lat_limits[2]   =   maximum([lat_limits[2]  maximum(DataSets[i].lat.val)]);

            z_limits[1]     =   minimum([z_limits[1]    minimum(DataSets[i].depth.val)]);
            z_limits[2]     =   maximum([z_limits[2]    maximum(DataSets[i].depth.val)]);
        end
    elseif isa(modelsize, Dict)
        lon_limits[1] = minimum(modelsize["lon"])
        lon_limits[2] = maximum(modelsize["lon"])
        lat_limits[1] = minimum(modelsize["lat"])
        lat_limits[2] = maximum(modelsize["lat"])
        z_limits[1] = minimum(-modelsize["depth"])
        z_limits[2] = maximum(-modelsize["depth"])
    else
        error("modelsize argument should bei either 'overlapping', 'maximum' or a Dictionary with entries 'lon','lat','depth'.")
    end

    # Loop over all datasets, and interpolate the data set to the new (usually smaller) domain
    if votes == "relative"
        VoteMap         =   zeros(dims)
    else
        VoteMap         =   zeros(Int64,dims)
    end
    ValidCounts         =   zeros(Int64,dims) # counts the number of models that have data coverage at each gridpoint
    for i=1:numDataSets
        VoteMap_Local   =   zeros(Int64,dims)
        
        # Interpolate data set to new domain (can be smaller or larger)
        # if the region is larger than the origional model domain, it performs a nearest neighor interpolation
        DataSet         =   ExtractSubvolume(DataSets[i]; Interpolate=true, Lon_level=lon_limits, Lat_level=lat_limits, Depth_level=z_limits, dims=dims);

        # these are the original model boundaries
        lon0,lon1  = [minimum(DataSets[i].lon.val);        maximum(DataSets[i].lon.val)];
        lat0,lat1  = [minimum(DataSets[i].lat.val);        maximum(DataSets[i].lat.val)];
        z0,z1    =   [minimum(DataSets[i].depth.val);      maximum(DataSets[i].depth.val)];  
        X,Y,Z = coordinate_grids(DataSet)

        # Extract the relevant array (e.g. dVp_Percentage))
        expr            =   Meta.parse(elements[i]);
        Array3D         =   ustrip.(DataSet.fields[expr[1]]);                  # strip units, just in case

        # Set all values to zero that are outside the original model area
        Array3D[(X.>lon1).+(X.<lon0).+(Y.>lat1).+(Y.<lat0).+(Z.>z1).+(Z.<z0) .!= 0] .= 0.

        # assuming all arrays have negative depth values, make sure that the input mindepth is also negative
        if mindepth > 0.
            mindepth = -mindepth
        end
        # To calculate mean and std, make sure that the data behaves well
        # 1) 0-values are often just dummyvalues for parts of the model that are outside the map region
        # 2) at shallow depths, <100km, P-traveltime tomography models are unreliable
        # 3) remove outliers > 5 stadev
        idx_valid = (Array3D .!= 0.)
        ValidCounts[idx_valid] .+= 1
        idx_valid = idx_valid .* (Z .< mindepth)
        idx_valid = idx_valid .* (abs.(Array3D) .< 5*std(Array3D[idx_valid]))
        # histogram(vcat(Array3D[idx_valid]...))
        if meancorrection # if meancorrection=true, correct for the mean
            Array3Dcorr = Array3D.-mean(Array3D[idx_valid]);
        else
            Array3Dcorr = Array3D
        end

        if threshold_stadev > 0.
            ind             = Array3Dcorr .> threshold_stadev*std(Array3Dcorr[idx_valid]);    # evaluate
        else
            ind             = Array3Dcorr .< threshold_stadev*std(Array3Dcorr[idx_valid]);    # evaluate
            VoteMap_Local[ind] .= 1;                 # assign vote-map
        end
        VoteMap = VoteMap + VoteMap_Local;       # Sum 
    end
    if votes == "relative"
        idx_valid = ValidCounts .> 0 # avoid division by zero
        VoteMap[idx_valid] ./= ValidCounts[idx_valid]
    end

    DataSet     =   ExtractSubvolume(DataSets[1], Interpolate=true, Lon_level=lon_limits, Lat_level=lat_limits, Depth_level=z_limits, dims=dims);

    # Construct GeoData set that holds the VoteMap (makes it easier to write paraview files)
    VoteData    =   GeoData(DataSet.lon.val,DataSet.lat.val,DataSet.depth.val, (VoteMap=VoteMap,));

    return VoteData
end


"""
    Data_R = RotateTranslateScale(Data::ParaviewData; Rotate=0, Translate=(0,0,0), Scale=(1.0,1.0,1.0))

Does an in-place rotation, translation and scaling of the Cartesian dataset `Data`. 

# Parameters
Note that we apply the transformations in exactly this order:
-   `Scale`:        scaling applied to the `x,y,z` coordinates of the data set
-   `Rotate`:       rotation around the `x/y` axis (around the center of the box)
-   `Translate`:    translation

# Example
```julia
julia> X,Y,Z   =   XYZGrid(10:20,30:40,-50:-10);
julia> Data_C  =   ParaviewData(X,Y,Z,(Depth=Z,))
ParaviewData 
  size  : (11, 11, 41)
  x     ϵ [ 10.0 : 20.0]
  y     ϵ [ 30.0 : 40.0]
  z     ϵ [ -50.0 : -10.0]
  fields: (:Depth,)
julia> Data_R = RotateTranslateScale(Data_C, Rotate=30);
julia> Data_R
ParaviewData 
  size  : (11, 11, 41)
  x     ϵ [ 8.169872981077807 : 21.83012701892219]
  y     ϵ [ 28.16987298107781 : 41.83012701892219]
  z     ϵ [ -50.0 : -10.0]
  fields: (:Depth,)
```
"""
function RotateTranslateScale(Data::ParaviewData; Rotate=0, Translate=(0,0,0), Scale=(1.0,1.0,1.0))

    X,Y,Z       = Data.x.val,   Data.y.val,     Data.z.val;         # Extract coordinates
    Xr,Yr,Zr    = X,Y,Z;                                            # Rotated coordinates 

    # 1) Scaling
    if length(Scale)==1
        Scale = [Scale Scale Scale];
    end
    Xr .*= Scale[1];
    Yr .*= Scale[2];
    Zr .*= Scale[3];


    # 2) 2D rotation around X/Y axis, around center of box
    Xm,Ym = mean(X), mean(Y);  
    R = [cosd(Rotate[1]) -sind(Rotate[1]); sind(Rotate[1]) cosd(Rotate[1])]; # 2D rotation matrix

    for i in eachindex(X)
        Rot_XY = R*[X[i]-Xm; Y[i]-Ym];
        Xr[i]  = Rot_XY[1] + Xm;
        Yr[i]  = Rot_XY[2] + Ym;
    end 
  
    # 3) Add translation
    Xr .+= Translate[1];
    Yr .+= Translate[2];
    Zr .+= Translate[3];
    
    # Modify original structure
    #Data.x.val = Xr;
    #Data.y.val = Yr;
    #Data.z.val = Zr;
    
    return ParaviewData(Xr,Yr,Zr, Data.fields)
end


"""
    Topo = DrapeOnTopo(Topo::GeoData, Data::GeoData) 

This drapes fields of a data set `Data` on the topography `Topo`    


"""
function DrapeOnTopo(Topo::GeoData, Data::GeoData)

    
    Lon,Lat,Depth    =   LonLatDepthGrid( Topo.lon.val[:,1,1], Topo.lat.val[1,:,1],Topo.depth.val[1,1,:]);

    # use nearest neighbour to interpolate data
    coord       =   [vec(Data.lon.val)'; vec(Data.lat.val)'];
    kdtree      =   KDTree(coord; leafsize = 10);
    points      =   [vec(Lon)';vec(Lat)'];
    idx,dist    =   nn(kdtree, points);


    idx_out     = findall(  (Lon .<  minimum(Data.lon.val)) .| (Lon .>  maximum(Data.lon.val)) .|
                            (Lat .<  minimum(Data.lat.val)) .| (Lat .>  maximum(Data.lat.val)) )
    
    fields_new  = Topo.fields;
    field_names = keys(Data.fields);
    
    for i = 1:length(Data.fields)
        
        if typeof(Data.fields[i]) <: Tuple

            # vector or anything that contains more than 1 field
            data_tuple = Data.fields[i]      # we have a tuple (likely a vector field), so we have to loop 

            data_array = zeros(typeof(data_tuple[1][1]),size(Topo.lon.val,1),size(Topo.lon.val,2),size(Topo.lon.val,3),length(Data.fields[i]));     # create a 3D array that holds the 2D interpolated values
            unit_array = zeros(size(data_array));

            for j=1:length(data_tuple)
                data_field           =   data_tuple[j];
                tmp                  =   data_array[:,:,:,1]; 
                tmp                  =   data_field[idx]
                data_array[:,:,:,j]  =   tmp
            end
            
            data_new    = tuple([data_array[:,:,:,c] for c in 1:size(data_array,4)]...)       # transform 4D matrix to tuple

            # remove points outside domain
            for j=1:length(data_tuple)
                tmp           =   data_new[j]; 
                tmp[idx_out] .= NaN
                data_array[:,:,:,j]  =   tmp
            end
            data_new    = tuple([data_array[:,:,:,c] for c in 1:size(data_array,4)]...)       # transform 4D matrix to tuple

        else
            
            # scalar field
            data_new        =   zeros(typeof(Data.fields[i][1]), size(Topo.lon.val,1),size(Topo.lon.val,2),size(Topo.lon.val,3));
            data_new        =   Data.fields[i][idx]                                 # interpolate data field
            
        end
        
        # replace the one 
        new_field   =   NamedTuple{(field_names[i],)}((data_new,))                          # Create a tuple with same name
        fields_new  =   merge(fields_new, new_field);                                       # replace the field in fields_new
        
    end 


    Topo_new        =   GeoData(Topo.lon.val,Topo.lat.val,Topo.depth.val, fields_new)

    return Topo_new

end


""" 
    DrapeOnTopo(Topo::CartData, Data::CartData)

Drapes Cartesian Data on topography 
"""
function DrapeOnTopo(Topo::CartData, Data::CartData)
    Topo_lonlat = GeoData(ustrip.(Topo.x.val),ustrip.(Topo.y.val), ustrip.(Topo.z.val), Topo.fields )
    Data_lonlat = GeoData(ustrip.(Data.x.val),ustrip.(Data.y.val), ustrip.(Data.z.val), Data.fields )

    Topo_new_lonlat = DrapeOnTopo(Topo_lonlat, Data_lonlat)

    Topo_new = CartData(Topo_new_lonlat.lon.val, Topo_new_lonlat.lat.val, Topo_new_lonlat.depth.val, Topo_new_lonlat.fields)

    return Topo_new
end

""" 
    LithostaticPressure!(Plithos::Array, Density::Array, dz::Number; g=9.81)

Computes lithostatic pressure from a 3D density array, assuming constant soacing `dz` in vertical direction. Optionally, the gravitational acceleration `g` can be specified.

"""
function LithostaticPressure!(Plithos::Array{T,N}, Density::Array{T,N}, dz::Number; g=9.81) where {T,N}
    
    Plithos[:] = Density*dz*g;
    
    selectdim(Plithos,N,size(Plithos)[N]) .= 0      # set upper row to zero
    
    Plithos[:] = reverse!(cumsum(reverse!(Plithos),dims=N))
    
    return nothing
end

