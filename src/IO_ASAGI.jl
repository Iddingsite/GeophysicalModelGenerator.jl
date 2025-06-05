# This allows creating ASAGI files from GMG structures, which can be used for example
# as input for codes such as SeisSol or ExaHype
#
# see https://github.com/TUM-I5/ASAGI
#
#

using NCDatasets
using NCDatasets: nc_create, NC_NETCDF4, NC_CLOBBER, NC_NOWRITE, nc_def_dim, nc_def_compound, nc_insert_compound, nc_def_var, nc_put_var, nc_close, NC_INT, nc_unsafe_put_var, libnetcdf, check, ncType, nc_open, nc_inq_vartype, nc_inq_compound_nfields, nc_inq_compound_size, nc_inq_compound_name, nc_inq_compound_fieldoffset, nc_inq_compound_fieldndims, nc_inq_compound_fielddim_sizes, nc_inq_compound_fieldname, nc_inq_compound_fieldindex, nc_inq_compound_fieldtype, nc_inq_compound, nc_inq_varid, nc_get_var!, nc_insert_array_compound, nc_def_vlen

export write_ASAGI, read_ASAGI

"""
    write_ASAGI(fname::String, Data::CartData; 
                        fields::Union{Nothing, Tuple}=nothing, 
                        km_to_m::Bool=false)
    
Writes a CartData structure `Data` to an ASAGI file, which can be read by SeisSol or ExaHype.
You can optionally pass a tuple with fields to be written. Note that we can only write individual (scalar) fields to disk,
so vector or tensor fields needs to be split first
"""
function write_ASAGI(
        fname::String, Data::CartData;
        fields::Union{Nothing, Tuple} = nothing,
        km_to_m::Bool = false
    )

    nx, ny, nz = size(Data.x)
    x = Data.x.val[:, 1, 1]
    y = Data.y.val[1, :, 1]
    z = Data.z.val[1, 1, :]
    if km_to_m == true
        println("convert to meters")
        x = x .* 1000
        y = y .* 1000
        z = z .* 1000
    end

    # Transfer data to a single array with NamedTuple entries
    material = fields_to_namedtuple(Data.fields, fields)

    fname_asagi = fname * "_ASAGI.nc"

    #ncid = nc_create(fname_asagi, NC_NETCDF4|NC_CLOBBER)
    ds = NCDataset(fname_asagi, "c", format = :netcdf4)

    # Write dimensions
    x_dimid = nc_def_dim(ds.ncid, "x", nx)
    y_dimid = nc_def_dim(ds.ncid, "y", ny)
    z_dimid = nc_def_dim(ds.ncid, "z", nz)

    v_x = defVar(ds, "x", eltype(x), ("x",))
    v_y = defVar(ds, "y", eltype(x), ("y",))
    v_z = defVar(ds, "z", eltype(x), ("z",))
    v_x[:] = x
    v_y[:] = y
    v_z[:] = z

    # add Tuple with data to file
    dimids = [x_dimid, y_dimid, z_dimid]
    T = eltype(material)
    typeid = nc_def_compound(ds.ncid, sizeof(T), "material")

    for i in 1:fieldcount(T)
        #local dim_sizes
        offset = fieldoffset(T, i)
        nctype = ncType[fieldtype(T, i)]
        nc_insert_compound(
            ds.ncid, typeid, fieldname(T, i),
            offset, nctype
        )
    end

    varid = nc_def_var(ds.ncid, "data", typeid, reverse(dimids))
    nc_put_var(ds.ncid, varid, material)

    # close file
    close(ds)

    return fname_asagi
end


# Transfer fields to a single array with NamedTuple entries
function fields_to_namedtuple(fields::NamedTuple, selected_fields)
    names = keys(fields)
    if !isnothing(selected_fields)
        names = selected_fields
    end
    nfield = length(names)
    ndim = length(size(fields[1]))

    s2 = NamedTuple{names}(zeros(nfield))

    # check that they are all DiskArrays
    for ifield in 1:nfield
        if !isa(getproperty(fields, names[ifield]), Array)
            @show typeof(getproperty(fields, names[ifield]))
            error("Field $(names[ifield]) is not an Array but instead a $(typeof(getproperty(fields, names[ifield]))); only Arrays are supported")
        end
    end

    material = Array{typeof(s2), ndim}(undef, size(fields[1]))
    for I in eachindex(material)
        data_local = []
        for ifield in 1:nfield
            push!(data_local, getproperty(fields, names[ifield])[I])

        end

        local_tup = NamedTuple{names}(data_local)

        material[I] = local_tup
    end

    return material
end

""" 
    data::CartData = read_ASAGI(fname_asagi::String)

This reads a 3D ASAGI NetCDF file, which is used as input for a number of codes such as SeisSol.
It returns a CartData dataset
"""
function read_ASAGI(fname_asagi::String)

    @assert fname_asagi[(end - 2):end] == ".nc"

    ds = NCDataset(fname_asagi, "r")

    x = ds["x"][:]
    y = ds["y"][:]
    z = ds["z"][:]

    nx, ny, nz = length(x), length(y), length(z)

    data_set_names = keys(ds)
    id = findall(data_set_names .!= "x" .&& data_set_names .!= "y" .&& data_set_names .!= "z")
    data_name = data_set_names[id]

    varid = nc_inq_varid(ds.ncid, data_name[1])
    xtype = nc_inq_vartype(ds.ncid, varid)

    # retrieve names of the fields
    numfields = nc_inq_compound_nfields(ds.ncid, xtype)
    cnames = Symbol.(nc_inq_compound_fieldname.(ds.ncid, xtype, 0:(numfields - 1)))

    types = []
    for fieldid in 0:(numfields - 1)
        local dim_sizes
        fT = NCDatasets.jlType[nc_inq_compound_fieldtype(ds.ncid, xtype, fieldid)]

        fieldndims = nc_inq_compound_fieldndims(ds.ncid, xtype, fieldid)

        if fieldndims == 0
            push!(types, fT)
        else
            dim_sizes = nc_inq_compound_fielddim_sizes(ds.ncid, xtype, fieldid)
            fT2 = NTuple{Int(dim_sizes[1]), fT}
            push!(types, fT2)
        end
    end

    # Create a single NamedTuple with correct type and names
    data_element = ()
    for ifield in 1:numfields
        data_element = (data_element..., types[ifield](0.0))
    end

    T2 = typeof(NamedTuple{(cnames...,)}(data_element))
    data = Array{T2, 3}(undef, nx, ny, nz)
    nc_get_var!(ds.ncid, varid, data)

    # At this stage, data is an array of NamedTuple with correct names & types
    #
    # Now split them into separate fields.
    read_fields_data = ()
    for ifield in 1:numfields
        data_1 = zeros(types[ifield], nx, ny, nz)

        for I in CartesianIndices(data)
            loc = data[I]
            data_1[I] = getproperty(loc, cnames[ifield])
        end

        read_fields_data = (read_fields_data..., data_1)
    end
    read_fields = NamedTuple{(cnames...,)}(read_fields_data)

    close(ds)

    return CartData(xyz_grid(x, y, z)..., read_fields)
end
