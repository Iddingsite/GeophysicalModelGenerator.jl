# Tests data_import.jl

using Test
using GeophysicalModelGenerator

# should throw an error with a 2D dataset
Lon, Lat, Depth = lonlatdepth_grid(10:20, 30:40, -50km);
Data1 = Depth * 2;                # some data
Vx1, Vy1, Vz1 = Data1 * 3, Data1 * 4, Data1 * 5
Data_set2D = GeoData(Lon, Lat, Depth, (Depthdata = Data1, LonData1 = Lon, Velocity = (Vx1, Vy1, Vz1)))
Data_set2D0 = GeoData(Lon, Lat, Depth, (Depthdata = Data1, LonData1 = Lon))
@test_throws ErrorException cross_section(Data_set2D, Depth_level = -10)

# Test interpolation of depth to a given cartesian XY-plane
x = 11:19
y = 31:39
plane1 = interpolate_datafields_2D(Data_set2D, x, y)
proj = ProjectionPoint()
plane2 = interpolate_datafields_2D(Data_set2D, proj, x, y)


Lon1, Lat1, Depth1 = lonlatdepth_grid(12:18, 33:39, -50km);
Data2 = Depth1 * 2;                # some data
Vx1, Vy1, Vz1 = Data2 * 3, Data2 * 4, Data2 * 5
Data_set2D_1 = GeoData(Lon1, Lat1, Depth1, (Depthdata1 = Data2, LonData2 = Lon1))

plane3 = interpolate_datafields_2D(Data_set2D0, Data_set2D_1)
@test sum(plane3.fields.Depthdata) ≈ -4900.0km


@test plane1 == plane2
@test all(==(-50.0e0), plane1)

# Create 3D volume with some fake data
Lon, Lat, Depth = lonlatdepth_grid(10:20, 30:40, (-300:25:0)km);
Data = Depth * 2;                # some data
Vx, Vy, Vz = ustrip(Data * 3) * km / s, ustrip(Data * 4) * km / s, ustrip(Data * 5) * km / s;
Data_set3D = GeoData(Lon, Lat, Depth, (Depthdata = Data, LonData = Lon, Velocity = (Vx, Vy, Vz)))

# Test addfield
Data_set3D = addfield(Data_set3D, "Lat", Lat)
@test keys(Data_set3D.fields) == (:Depthdata, :LonData, :Velocity, :Lat)

Data_set3D = addfield(Data_set3D, (; Lat, Lon))
@test keys(Data_set3D.fields) == (:Depthdata, :LonData, :Velocity, :Lat, :Lon)

# test removefield
Data_set3D_1 = removefield(Data_set3D, "Lon")
@test keys(Data_set3D_1.fields) == (:Depthdata, :LonData, :Velocity, :Lat)

Data_set3D_2 = removefield(Data_set3D, :Lon)
@test keys(Data_set3D_2.fields) == (:Depthdata, :LonData, :Velocity, :Lat)

Data_set3D_3 = removefield(Data_set3D, (:Lon, :Lat))
@test keys(Data_set3D_3.fields) == (:Depthdata, :LonData, :Velocity)

# Create 3D cartesian dataset
Data_setCart3D = CartData(Lon, Lat, Depth, (Depthdata = Data, LonData = Lon, Velocity = (Vx, Vy, Vz)))

# Create 3D volume with some fake data
Lon, Lat, Depth = lonlatdepth_grid(10:20, 30:40, (0:-25:-300)km);
Data = Depth * 2;                # some data
Vx, Vy, Vz = ustrip(Data * 3) * km / s, ustrip(Data * 4) * km / s, ustrip(Data * 5) * km / s;
Data_set3D_reverse = GeoData(Lon, Lat, Depth, (Depthdata = Data, LonData = Lon, Velocity = (Vx, Vy, Vz)))

# Create cross-sections in various directions (no interpolation which is default)
test_cross = cross_section(Data_set3D, Depth_level = -100km)
@test test_cross.fields[1][41] == -200km
@test test_cross.fields[2][31] == 18
@test test_cross.fields[3][1][30] == -600km / s
@test test_cross.fields[3][2][30] == -800km / s
@test test_cross.fields[3][3][30] == -1000km / s

# throw error if outside bounds
@test_throws ErrorException cross_section(Data_set3D, Depth_level = 100km)

test_cross = cross_section(Data_set3D, Lon_level = 15)
@test test_cross.fields[1][41] == -450km
@test test_cross.fields[2][31] == 15
@test test_cross.fields[3][1][30] == -1500km / s
@test test_cross.fields[3][2][30] == -2000km / s
@test test_cross.fields[3][3][30] == -2500km / s

test_cross = cross_section(Data_set3D, Lat_level = 35)
@test test_cross.fields[1][41] == -450km
@test test_cross.fields[2][31] == 18
@test test_cross.fields[3][1][30] == -1500km / s
@test test_cross.fields[3][2][30] == -2000km / s
@test test_cross.fields[3][3][30] == -2500km / s

# Create cross-sections with interpolation in various directions
test_cross = cross_section(Data_set3D, Depth_level = -100km, dims = (50, 100), Interpolate = true)
@test size(test_cross.fields[1]) == (50, 100, 1)
@test size(test_cross.fields[3][2]) == (50, 100, 1)

test_cross = cross_section(Data_set3D, Lon_level = 15, dims = (50, 100), Interpolate = true)
@test size(test_cross.fields[3][2]) == (1, 50, 100)
@test write_paraview(test_cross, "profile_test") == nothing

test_cross = cross_section(Data_set3D, Lat_level = 35, dims = (50, 100), Interpolate = true)
@test size(test_cross.fields[3][2]) == (50, 1, 100)

# Diagonal cross-section
test_cross = cross_section(Data_set3D, Start = (10, 30), End = (20, 40), dims = (50, 100), Interpolate = true)
@test size(test_cross.fields[3][2]) == (50, 100, 1)
@test write_paraview(test_cross, "profile_test") == nothing

#test_cross_rev  =   cross_section(Data_set3D_reverse, Start=(10,30), End=(20,40), dims=(50,100), Interpolate=true)
#@test size(test_cross_rev.fields[3][2])==(50,100,1)
#@test write_paraview(test_cross_rev, "profile_test_rev")[1]=="profile_test_rev.vts"

# Cross section of a topography
depth_values = [rand(0:0.1:3.5)]
Lon, Lat, Depth = lonlatdepth_grid(10:20, 30:40, depth_values[:]);
Data_Topo = GeoData(Lon, Lat, Depth, (Depthdata = Depth,))
Data_Topo_geo = cross_section(Data_Topo, Start = (10, 30), End = (20, 40), dims = (50, 100), Interpolate = true)
@test Data_Topo_geo isa GeoData

Lon, Lat, Depth = lonlatdepth_grid(5:25, 20:50, 0);
Depth = cos.(Lon / 5) .* sin.(Lat) * 10;
Data_surf = GeoData(Lon, Lat, Depth, (Z = Depth,));
Data_surf_cart = convert2CartData(Data_surf, proj);
Data_surf_cross = cross_section(Data_surf_cart, Start = (-1693, 2500), End = (-1000, 3650), dims = (50, 100), Interpolate = true)
@test Data_surf_cross isa CartData

# Cross-section with cartesian data
test_cross = cross_section(Data_setCart3D, Lon_level = 15, dims = (50, 100), Interpolate = true)
@test size(test_cross.fields[3][2]) == (1, 50, 100)
@test test_cross.x[1, 2, 3] == GeoUnit(15km)

# Flatten diagonal 3D cross_section with CartData

# Create 3D volume with some fake data
Grid = create_CartGrid(size = (100, 100, 100), x = (0.0km, 99.9km), y = (-10.0km, 20.0km), z = (-40km, 4km));
X, Y, Z = xyz_grid(Grid.coord1D...);
DataSet_Cart = CartData(X, Y, Z, (Depthdata = Z,))

test_cross_cart = cross_section(DataSet_Cart, dims = (100, 100), Interpolate = true, Start = (ustrip(Grid.min[1]), ustrip(Grid.max[2])), End = (ustrip(Grid.max[1]), ustrip(Grid.min[2])))

flatten_cross = flatten_cross_section(test_cross_cart)

@test flatten_cross[2][30] == 1.0536089537226578
@test test_cross_cart.fields.FlatCrossSection[2][30] == flatten_cross[2][30] # should be added by default

# Flatten 3D cross_section with GeoData
Lon, Lat, Depth = lonlatdepth_grid(10:20, 30:40, (-300:25:0)km);
Data = Depth * 2;                # some data
Data_set = GeoData(Lon, Lat, Depth, (Depthdata = Data,));
Data_cross = cross_section(Data_set, Start = (10, 39), End = (10, 40))
x_profile = flatten_cross_section(Data_cross)

@test x_profile[100][100][1] == 111.02363637836613


# Extract sub-volume

# with interpolation
Data_sub_Interp = extract_subvolume(Data_set3D, Lon_level = (10, 15), Lat_level = (30, 32), Interpolate = true, dims = (51, 21, 32))
@test Data_sub_Interp.fields[1][11] == -600km
@test size(Data_sub_Interp.lat) == (51, 21, 32)

Data_sub_Interp_Cart = extract_subvolume(DataSet_Cart, X_level = (10, 15), Y_level = (10, 12), Interpolate = true, dims = (51, 21, 32))
@test Data_sub_Interp_Cart.fields[1][11] == -40km
@test size(Data_sub_Interp_Cart.x) == (51, 21, 32)

Data_cross_Interp_Cart = extract_subvolume(test_cross_cart, X_level = (10, 50), Z_level = (-20, -5), dims = (51, 61))
@test Data_cross_Interp_Cart.fields[1][11] == 18.0
@test size(Data_cross_Interp_Cart.x) == (51, 61, 1)

# no interpolation
Data_sub_NoInterp = extract_subvolume(Data_set3D, Lon_level = (10, 15), Lat_level = (30, 32), Interpolate = false, dims = (51, 21, 32))
@test Data_sub_NoInterp.fields[1][11] == -600km
@test size(Data_sub_NoInterp.lat) == (6, 3, 13)

Data_sub_Interp_Cart = extract_subvolume(DataSet_Cart, X_level = (10, 15), Y_level = (10, 12), Interpolate = false, dims = (51, 21, 32))
@test Data_sub_Interp_Cart.fields[1][5] == -40km
@test size(Data_sub_Interp_Cart.x) == (6, 8, 100)


# Extract subset of cross-section
test_cross = cross_section(Data_set3D, Lat_level = 35, dims = (50, 100), Interpolate = true)
Data_sub_cross = extract_subvolume(test_cross, Depth_level = (-100km, 0km), Interpolate = false)
@test Data_sub_cross.fields[1][11] == -200.00000000000003km
@test size(Data_sub_cross.lat) == (50, 1, 34)

test_cross_cart = cross_section(DataSet_Cart, Start = (0.0, -9.0), End = (90.0, 19.0)) # Cartesian cross-section


# compute the mean velocity per depth in a 3D dataset and subtract the mean from the given velocities
Data_pert = subtract_horizontalmean(ustrip(Data))    # 3D, no units
@test Data_pert[10] == 0.0

Data_pert = subtract_horizontalmean(Data)            # 3D with units
@test Data_pert[10] == 0.0km

Data_pert = subtract_horizontalmean(Data, Percentage = true)            # 3D with units
@test Data_pert[1000] == 0.0

Data2D = Data[:, 1, :];
Data_pert = subtract_horizontalmean(Data2D, Percentage = true)         # 2D version with units [dp the same along a vertical profile]

Data_set2D = GeoData(Lon, Lat, Depth, (Depthdata = Data, LonData = Lon, Pertdata = Data_pert, Velocity = (Vx, Vy, Vz)))
@test Data_set2D.fields[3][10, 8, 1] == 0


# Create surface ("Moho")
Lon, Lat, Depth = lonlatdepth_grid(10:20, 30:40, -40km);
Depth = Depth + Lon * km;     # some fake topography on Moho
Data_Moho = GeoData(Lon, Lat, Depth, (MohoDepth = Depth, LonData = Lon, TestData = (Depth, Depth, Depth)))


# Test intersecting a surface with 2D or 3D data sets
Above = above_surface(Data_set3D, Data_Moho);            # 3D regular ordering
@test Above[1, 1, 12] == true
@test Above[1, 1, 11] == false

Above = above_surface(Data_set3D_reverse, Data_Moho);    #  3D reverse depth ordering
@test Above[1, 1, 2] == true
@test Above[1, 1, 3] == false

Above = above_surface(Data_sub_cross, Data_Moho);        # 2D cross-section
@test Above[end] == true
@test Above[1] == false

# test profile creation of surface data
test_cross = cross_section(Data_Moho, dims = (101,), Lat_level = 37.5)
@test test_cross.fields.MohoDepth[8] == -29.3km

test_cross = cross_section(Data_Moho, dims = (101,), Lon_level = 15.8)
@test test_cross.fields.MohoDepth[11] == -24.2km

test_cross = cross_section(Data_Moho, dims = (101,), Start = (10, 30), End = (20, 40))
@test test_cross.fields.MohoDepth[30] == -27.1km


# Test VoteMaps
Data_VoteMap = votemap(Data_set3D, "Depthdata<-560", dims = (10, 10, 10))
@test Data_VoteMap.fields[:votemap][101] == 0
@test Data_VoteMap.fields[:votemap][100] == 1

Data_VoteMap = votemap(Data_set3D_reverse, "Depthdata<-560", dims = (10, 10, 10))
@test Data_VoteMap.fields[:votemap][101] == 0
@test Data_VoteMap.fields[:votemap][100] == 1

# Combine 2 datasets
Data_VoteMap = votemap([Data_set3D_reverse, Data_set3D], ["Depthdata<-560", "LonData>19"], dims = (10, 10, 10))
@test Data_VoteMap.fields[:votemap][10, 9, 1] == 2
@test Data_VoteMap.fields[:votemap][9, 9, 1] == 1
@test Data_VoteMap.fields[:votemap][9, 9, 2] == 0

# Test rotation routines
X, Y, Z = lonlatdepth_grid(10:20, 30:40, -50:-10);
Data_C = ParaviewData(X, Y, Z, (Depth = Z,))
Data_C1 = rotate_translate_scale(Data_C, Rotate = 30);
@test Data_C1.x.val[10] ≈ 1.4544826719043336
@test Data_C1.y.val[10] ≈ 35.48076211353316
@test Data_C1.z.val[20] == -50

Data_C1 = rotate_translate_scale(Data_C, Scale = 10, Rotate = 10, Translate = (1, 2, 3));
@test Data_C1.x.val[10] ≈ 136.01901977224043
@test Data_C1.y.val[10] ≈ 330.43547966037914
@test Data_C1.z.val[20] == -497.0

# create point data set (e.g. Earthquakes)
Lon, Lat, Depth = lonlatdepth_grid(15:0.05:17, 35:0.05:37, 280km);
Depth = Depth - 20 * Lon * km;     # some variation in depth
Magnitude = rand(size(Depth, 1), size(Depth, 2), size(Depth, 3)) * 6; # some magnitude
TestVecField = (Magnitude[:], Magnitude[:], Magnitude[:])

Data_EQ = GeoData(Lon[:], Lat[:], Depth[:], (depth = Depth[:], Magnitude = Magnitude[:], VecField = TestVecField))

# Test profile creation from point data set
cross_tmp = cross_section(Data_EQ, Depth_level = -25km, section_width = 10km)
@test cross_tmp.fields.depth_proj[10] == -25km # check if the projected depth level is actually the chosen one

cross_tmp = cross_section(Data_EQ, Lat_level = 36.2, section_width = 10km)
@test cross_tmp.fields.lat_proj[10] == 36.2 # check if the projected latitude level is the chosen one

cross_tmp = cross_section(Data_EQ, Lon_level = 16.4, section_width = 10km)
@test cross_tmp.fields.lon_proj[10] == 16.4 # check if the projected longitude level is the chosen one
cross_tmp = cross_section(Data_EQ, Start = (15.0, 35.0), End = (17.0, 37.0), section_width = 10km)
@test cross_tmp.fields.lon_proj[20] == 15.314329874961091
@test cross_tmp.fields.lat_proj[20] == 35.323420618580585

# test inPolygon
PolyX = [-2.0, -1, 0, 1, 2, 1, 3, 3, 8, 3, 3, 1, 2, 1, 0, -1, -2, -1, -3, -3, -8, -3, -3, -1, -2]
PolyY = [3.0, 3, 8.01, 3, 3, 1, 2, 1, 0, -1, -2, -1, -3, -3, -8, -3, -3, -1, -2, -1, 0, 1, 2, 1, 3]
xvec = collect(-9:0.5:9); yvec = collect(-9:0.5:9); zvec = collect(1.0:1.0);
X, Y, Z = meshgrid(xvec, yvec, zvec)
X, Y = X[:, :, 1], Y[:, :, 1]
yN = zeros(Bool, size(X))
inpolygon!(yN, PolyX, PolyY, X, Y, fast = true)
@test sum(yN) == 194
inpolygon!(yN, PolyX, PolyY, X, Y)
@test sum(yN) == 217
X, Y, yN = X[:], Y[:], yN[:]
inpolygon!(yN, PolyX, PolyY, X, Y, fast = true)
@test sum(yN) == 194
inpolygon!(yN, PolyX, PolyY, X, Y)
@test sum(yN) == 217


# add cell and vertex fields
q1_data = Q1Data(xyz_grid(1:10, 1:10, 1:8))
q1_data = addfield(q1_data, (region = zeros(Int64, size(q1_data)),), cellfield = true)
@test keys(q1_data.fields) == (:Z,)
@test keys(q1_data.cellfields) == (:region,)

# Q1 data
q1_data = addfield(q1_data, (T = ones(Float64, size(q1_data) .+ 1),))
@test keys(q1_data.fields) == (:Z, :T)
@test keys(q1_data.cellfields) == (:region,)


# FE data
fe_data = convert2FEData(q1_data)
@test size(fe_data.fields.Z) == (800,)

fe_data = addfield(fe_data, (T1 = ones(Float64, size(fe_data.fields.Z)),))
@test keys(fe_data.fields) == (:Z, :T, :T1)
