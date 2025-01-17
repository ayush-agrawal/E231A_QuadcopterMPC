%%
% quadrotorDifferentialFlatness.m


%%
syms y z phi dy dz dphi d2y d2z d2phi d3y d3z d3phi d4y d4z d4phi real
syms mQ JQ f M g real

x = [y; z; phi; dy; dz; dphi];
dx = [dy; dz; dphi; d2y; d2z; d2phi];

phi = atan2(-d2y,(d2z+g))
dphi = simplify(jacobian(phi,[d2y,d2z])*[d3y; d3z])
d2phi = simplify(jacobian(dphi,[d2y,d2z, d3y, d3z])*[d3y; d3z; d4y; d4z])

