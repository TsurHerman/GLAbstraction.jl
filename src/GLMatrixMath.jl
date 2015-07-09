#some workaround for missing generic constructors in fixedsizearrays
function Base.convert(a::Type{Matrix3x3}, b::Matrix4x4)
    Matrix3x3(
        b[1,1], b[1,2], b[1,3],
        b[2,1], b[2,2], b[2,3],
        b[3,1], b[3,2], b[3,3],
    )
end

function scalematrix{T}(s::Vector3{T})
    T0, T1 = zero(T), one(T)
    Matrix4x4{T}(
        s[1],T0,  T0,  T0,
        T0,  s[2],T0,  T0,
        T0,  T0,  s[3],T0,
        T0,  T0,  T0,  T1,
    )
end

translationmatrix_x{T}(x::T) = translationmatrix(Vector3{T}(x, 0, 0))
translationmatrix_y{T}(y::T) = translationmatrix(Vector3{T}(0, y, 0))
translationmatrix_z{T}(z::T) = translationmatrix(Vector3{T}(0, 0, z))

function translationmatrix{T}(t::Vector3{T})
    T0, T1 = zero(T), one(T)
    Matrix4x4{T}(
        T1,  T0,  T0,  T0,
        T0,  T1,  T0,  T0,
        T0,  T0,  T1,  T0,
        t[1],t[2],t[3],T1, 
    )
end

rotate{T}(angle::T, axis::Vector3{T}) = rotationmatrix(qrotation(convert(Array, axis), angle))

function rotationmatrix_x{T}(angle::T)
    T0, T1 = zero(T), one(T)
    Matrix4x4{T}(
        T1, T0, T0, T0,
        T0, cos(angle), -sin(angle), T0,
        T0, sin(angle), cos(angle),  T0,
        T0, T0, T0, T1
    )
end
function rotationmatrix_y{T}(angle::T)
    T0, T1 = zero(T), one(T)
    Matrix4x4{T}(
        cos(angle), T0, sin(angle),  T0,
        T0, T1, T0, T0,
        -sin(angle), T0, cos(angle), T0,
        T0, T0, T0, T1
    )
end
function rotationmatrix_z{T}(angle::T)
    T0, T1 = zero(T), one(T)
    Matrix4x4{T}(
        cos(angle), -sin(angle), T0, T0,
        sin(angle), cos(angle),  T0, T0,
        T0, T0, T1, T0,
        T0, T0, T0, T1
    )
end
#=
    Create view frustum

    Parameters
    ----------
        left : float
         Left coordinate of the field of view.
        right : float
         Left coordinate of the field of view.
        bottom : float
         Bottom coordinate of the field of view.
        top : float
         Top coordinate of the field of view.
        znear : float
         Near coordinate of the field of view.
        zfar : float
         Far coordinate of the field of view.

    Returns
    -------
        M : array
         View frustum matrix (4x4).
=#
function frustum{T}(left::T, right::T, bottom::T, top::T, znear::T, zfar::T)
    (right == left || bottom == top || znear == zfar) && return eye(Matrix4x4{T})
    T0, T2 = zero(T), T(2)
    return Matrix4x4{T}(
        T2 * znear / (right - left), T0, (right + left) / (right - left), T0,
        T0, T2 * znear / (top - bottom), T0, (top + bottom) / (top - bottom),
        T0, T0, -(zfar + znear) / (zfar - znear), -T2 * znear * zfar / (zfar - znear),
        T0, T0, -one(T), T0
    )
end

function perspectiveprojection{T}(fovy::T, aspect::T, znear::T, zfar::T)
    (znear == zfar) && error("znear ($znear) must be different from tfar ($zfar)")
    h = T(tan(fovy / 360.0 * pi) * znear)
    w = T(h * aspect)
    return frustum(-w, w, -h, h, znear, zfar)
end

function lookat{T}(eyePos::Vector3{T}, lookAt::Vector3{T}, up::Vector3{T})
    zaxis  = normalize(eyePos-lookAt)
    xaxis  = normalize(cross(up,    zaxis))
    yaxis  = normalize(cross(zaxis, xaxis))
    T0, T1 = zero(T), one(T)
    return Matrix4x4{T}(
        xaxis[1], yaxis[1], zaxis[1], T0,
        xaxis[2], yaxis[2], zaxis[2], T0,
        xaxis[3], yaxis[3], zaxis[3], T0,
        T0,       T0,       T0,       T1 
    ) * translationmatrix(-eyePos)
end
orthographicprojection{T}(wh::Rectangle, near::T, far::T) = 
    orthographicprojection(zero(T), convert(T, wh.w), zero(T), convert(T, wh.h), near, far)

function orthographicprojection{T}(
        left  ::T, right::T,
        bottom::T, top  ::T,
        znear ::T, zfar ::T
    )
    (right==left || bottom==top || znear==zfar) && return eye(Matrix4x4{T})
    T0, T1, T2 = zero(T), one(T), T(2)
    Matrix4x4{T}(
        T2/(right-left), T0, T0,  T0,
        T0, T2/(top-bottom), T0,  T0,
        T0, T0, -T2/(zfar-znear), T0,
        -(right+left)/(right-left), -(top+bottom)/(top-bottom), -(zfar+znear)/(zfar-znear), T1
    )
end


import Base: (*)
function (*){T}(q::Quaternions.Quaternion{T}, v::Vector3{T}) 
    t = T(2) * cross(Vector3(q.v1, q.v2, q.v3), v)
    v + q.s * t + cross(Vector3(q.v1, q.v2, q.v3), t)
end
function Quaternions.qrotation{T<:Real}(axis::Vector3{T}, theta::T)
    u = normalize(axis)
    s = sin(theta/2)
    Quaternions.Quaternion(cos(theta/2), s*u[1], s*u[2], s*u[3], true)
end

immutable Pivot{T}
    origin      ::Vector3{T}
    xaxis       ::Vector3{T}
    yaxis       ::Vector3{T}
    zaxis       ::Vector3{T}
    rotation    ::Quaternions.Quaternion
    translation ::Vector3{T}
    scale       ::Vector3{T}
end
function rotationmatrix4{T}(q::Quaternions.Quaternion{T})
    sx, sy, sz = 2q.s*q.v1,  2q.s*q.v2,   2q.s*q.v3
    xx, xy, xz = 2q.v1^2,    2q.v1*q.v2,  2q.v1*q.v3
    yy, yz, zz = 2q.v2^2,    2q.v2*q.v3,  2q.v3^2
    T0, T1 = zero(T), one(T)
    Matrix4x4{T}(
        T1-(yy+zz), xy+sz,      xz-sy,      T0,
        xy-sz,      T1-(xx+zz), yz+sx,      T0,
        xz+sy,      yz-sx,      T1-(xx+yy), T0,
        T0,         T0,         T0,         T1
    )
end
transformationmatrix(p::Pivot) = (
    translationmatrix(p.origin) * #go to origin
    rotationmatrix4(p.rotation) * #apply rotation
    translationmatrix(-p.origin)* # go back to origin
    translationmatrix(p.translation) #apply translation
) 
#Calculate rotation between two vectors
function rotation{T}(u::Vector3{T}, v::Vector3{T})
    # It is important that the inputs are of equal length when
    # calculating the half-way vector.
    u, v = normalize(u), normalize(v)
    # Unfortunately, we have to check for when u == -v, as u + v
    # in this case will be (0, 0, 0), which cannot be normalized.
    if (u == -v)
        # 180 degree rotation around any orthogonal vector
        other = (abs(dot(u, Vector3{T}(1,0,0))) < 1.0) ? Vector3{T}(1,0,0) : Vector3{T}(0,1,0)
        return Quaternions.qrotation(normalize(cross(u, other)), T(180))
    end
    half = normalize(u+v)
    return Quaternions.Quaternion(dot(u, half), cross(u, half)...)
end


