function [NewRA,NewDec]=subimage_coo(RA,Dec,X,Y,CCDSEC, Scale, Flip,Rotation)
% given RA/Dec at X/Y convert to RA/Dec at CCDSEC center
% Package: +lastpipe.util
% Input  : - RA [deg]
%          - Dec [deg]
%          - X position corresponding to RA,Dec
%          - Y position corresponding to RA,Dec
%          - CCDSEC [Xmin Xmax Ymin Ymax] of a sub image.
%            Alternatively [X,Y] position in which to calculate the new
%            RA,Dec.
%          - Pixel scale ["/pix].
%          - Flip. Default is [1 1].
%          - Rotation (position angle) [deg] of the Y axis. Default is 0.
% Output : - RA at the center of the CCDSEC.
%          - Dec at the center of the CCDSEC.
% Example: lastpipe.util.subimage_coo(RA,Dec,X,Y,CCDSEC, Flip,Rotation)
%          lastpipe.util.subimage_coo(10,30,100,100,[200 200], 1, [1 1],[0])

ARCSEC_DEG = 3600;

if nargin<8
    Rotation = 0;
    if nargin<7
        Flip = [1 1];
    end
end

if numel(CCDSEC)==4
    Xnew = (CCDSEC(1)+CCDSEC(2)).*0.5;
    Ynew = (CCDSEC(3)+CCDSEC(4)).*0.5;
elseif numel(CCDSEC)==2
    Xnew = CCDSEC(1);
    Ynew = CCDSEC(2);
else
    error('Unknown CCDSEC format');
end
    
DX = Xnew - X;
DY = Ynew - Y;
DX = DX.*Flip(1);
DY = DY.*Flip(2);

RotMat = [cosd(-Rotation) -sind(-Rotation);  sin(-Rotation) cos(-Rotation)];
NewXY  = RotMat*[DX;DY];
DX     = NewXY(1);
DY     = NewXY(2);


PA   = atan2d(DX,DY);
Dist = sqrt(DX.^2 + DY.^2);

[NewDec,NewRA] = reckon(Dec,RA,Dist.*Scale./ARCSEC_DEG,PA,'degrees');

% RA in 0..2pi range
NewRA = mod(NewRA,360); 


