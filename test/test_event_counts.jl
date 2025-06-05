using Test

# Create a CartGrid
Grid_cart = CartData(xyz_grid(-20:20, -20:0.1:20, -30:30))

Lon, Lat, Depth = lonlatdepth_grid(-20:20, -20:0.1:20, -30:30);
Grid_geo = GeoData(Lon, Lat, Depth, (; Depth))

# create 2D GeoData struct
Lon, Lat, Depth = lonlatdepth_grid(10:20, 30:40, 0);
CM = zeros(size(Depth)); CM[1:5, 1:5] .= 1.0
Data_set2D = GeoData(Lon, Lat, Depth, (Count = CM,))

using StableRNGs

rng = StableRNG(123)

# Create some random point data
pt = rand(rng, 10_000, 3) .- 0.5
pt[:, 1] .*= 20
pt[:, 2] .*= 20
pt[:, 3] .*= 30

EQ_cart = CartData(pt[:, 1], pt[:, 2], pt[:, 3], (z = pt[:, 3],))
EQ_geo = GeoData(pt[:, 1], pt[:, 2], pt[:, 3], (z = pt[:, 3],))

R = (sum(pt .^ 2, dims = 2)) .^ (1 / 3)
ind = findall(R .< 5);

# test the basic routine
counts = point_to_nearest_grid(pt[:, 1], pt[:, 2], pt[:, 3], NumValue(Grid_cart.x), NumValue(Grid_cart.y), NumValue(Grid_cart.z); radius_factor = 2)
@test extrema(counts) == (0, 85)

# Test if the grid is on a CartData grid
Grid_Count = point_to_nearest_grid(pt[:, 1], pt[:, 2], pt[:, 3], Grid_cart; radius_factor = 2)
@test extrema(Grid_Count.fields.Count) == (0, 85)

# Test in case the EQ data is also specified as CartData
Grid_Count = point_to_nearest_grid(EQ_cart, Grid_cart; radius_factor = 2)
@test extrema(Grid_Count.fields.Count) == (0, 85)

# Test if the grid is on a GeoData grid
Grid_Count = point_to_nearest_grid(pt[:, 1], pt[:, 2], pt[:, 3], Grid_geo; radius_factor = 2)
@test extrema(Grid_Count.fields.Count) == (0, 85)

# Test in case the EQ data is also specified as GeoData
Grid_Count = point_to_nearest_grid(EQ_geo, Grid_geo; radius_factor = 2)
@test extrema(Grid_Count.fields.Count) == (0, 85)

# Test countmap
Data_countMap = countmap(Data_set2D, "Count", 5, 5)
@test Data_countMap.fields.countmap[1, 1] == 1.0
@test Data_countMap.fields.countmap[2, 2] == 0.4444444444444444
@test Data_countMap.fields.countmap[4, 4] == 0.0
