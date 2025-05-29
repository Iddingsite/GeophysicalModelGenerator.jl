using Test
# test various surface routines

# Create surfaces
cartdata1 = CartData(xyz_grid(1:4, 1:5, 0))
cartdata2 = CartData(xyz_grid(1:4, 1:5, 2))
cartdata3 = CartData(xyz_grid(1:4, 1:5, 2:5))
cartdata2 = addfield(cartdata2, "Z2", cartdata2.x.val)

@test is_surface(cartdata1)
@test is_surface(cartdata2)
@test is_surface(cartdata3) == false

geodata1 = GeoData(lonlatdepth_grid(1:4, 1:5, 0))
geodata2 = GeoData(lonlatdepth_grid(1:4, 1:5, 2))
geodata3 = GeoData(lonlatdepth_grid(1:4, 1:5, 2:5))

@test is_surface(geodata1)
@test is_surface(geodata2)
@test is_surface(geodata3) == false

# Test add & subtraction of surfaces
cartdata4 = cartdata1 + cartdata2
@test length(cartdata4.fields) == 2
@test cartdata4.z.val[2] == 2.0

cartdata5 = cartdata1 - cartdata2
@test length(cartdata5.fields) == 2
@test cartdata5.z.val[2] == -2.0

geodata4 = geodata1 + geodata2
@test length(geodata4.fields) == 1
@test geodata4.depth.val[2] == 2.0

geodata5 = geodata1 - geodata2
@test length(geodata5.fields) == 1
@test geodata5.depth.val[2] == -2.0

# Test removing NaN;
Z = NumValue(cartdata5.z)
Z[2, 2] = NaN;
remove_NaN_surface!(Z, NumValue(cartdata5.x), NumValue(cartdata5.y))
@test any(isnan.(Z)) == false

# Test draping values on topography
X, Y, Z = xyz_grid(1:0.14:4, 1:0.02:5, 0);
v = X .^ 2 .+ Y .^ 2;
values1 = CartData(X, Y, Z, (; v))
values2 = CartData(X, Y, Z, (; colors = (v, v, v)))

cart_drape1 = drape_on_topo(cartdata2, values1)
@test  sum(cart_drape1.fields.v) ≈ 366.02799999999996

cart_drape2 = drape_on_topo(cartdata2, values2)
@test  cart_drape2.fields.colors[1][10] ≈ 12.9204

values1 = GeoData(X, Y, Z, (; v))
values2 = GeoData(X, Y, Z, (; colors = (v, v, v)))

geo_drape1 = drape_on_topo(geodata2, values1)
@test  sum(geo_drape1.fields.v) ≈ 366.02799999999996

geo_drape2 = drape_on_topo(geodata2, values2)
@test  geo_drape2.fields.colors[1][10] ≈ 12.9204

# test fit_surface_to_points
cartdata2b = fit_surface_to_points(cartdata2, X[:], Y[:], v[:])
@test sum(NumValue(cartdata2b.z)) ≈ 366.02799999999996


#-------------
# test above_surface with the Grid object
Grid = create_CartGrid(size = (10, 20, 30), x = (0.0, 10), y = (0.0, 10), z = (-10.0, 2.0))
@test Grid.Δ[2] ≈ 0.5263157894736842

Temp = ones(Float64, Grid.N...) * 1350;
Phases = zeros(Int32, Grid.N...);

Topo_cart = CartData(xyz_grid(-1:0.2:20, -12:0.2:13, 0));
ind = above_surface(Grid, Topo_cart);
@test sum(ind[1, 1, :]) == 5

ind = below_surface(Grid, Topo_cart);
@test sum(ind[1, 1, :]) == 25


#-------------
# test above_surface with the Q1Data object
q1data = Q1Data(xyz_grid(1:4, 1:5, -5:5))
ind = above_surface(q1data, cartdata2);
@test sum(ind) == 60

ind = below_surface(q1data, cartdata2);
@test sum(ind) == 140
