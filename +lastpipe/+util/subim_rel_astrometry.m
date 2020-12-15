function subim_rel_astrometry(AllImages)
%

CenterX = (InPar.SubCCDSEC(:,1)+InPar.SubCCDSEC(:,2)).*0.5;
CenterY = (InPar.SubCCDSEC(:,3)+InPar.SubCCDSEC(:,4)).*0.5;


Max = max(InPar.SubCCDSEC)
ArrayXcenter = Max(2)./2;
ArrayYcenter = Max(4)./2;

Dist = sqrt((CenterX - ArrayXcenter).^2 + (CenterY - ArrayYcenter).^2);
[~,SI] = sort(Dist);


Iim = 1;
            
            % ObsGeoPos [deg]
            Res = imUtil.patternMatch.fit_astrometry(AllImages(Iim,Isub).Cat,KeyValFitAstrom{:},'RA',RA,'Dec',Dec,...
                                                                                                'CooUnits','deg',...
                                                                                                'Size',[1.5 1.5],...
                                                                                                'ObsGeoPos',[Config.Mount.Long, Config.Mount.Lat],...
                                                                                                'Flip',[-1 -1],...
                                                                                                'Tran',Tran);
            
            % is the astrometric solution to calculate sources positions
            
            % Xsrc, Ysrc are measured realtive to image center???
            InPar.ColX = 'X';
            InPar.ColY = 'Y';
            
            ColX   = col_bestFromList(AllImages(Iim,Isub).Cat, InPar.ColX);
            ColY   = col_bestFromList(AllImages(Iim,Isub).Cat, InPar.ColY);
            
            X    = AllImages(Iim,Isub).Cat.Cat(:,ColX);
            Y    = AllImages(Iim,Isub).Cat.Cat(:,ColY);
            
            Xsrc = X - Res.Cat.CenterCat(:,1);
            Ysrc = Y - Res.Cat.CenterCat(:,2);
            [Xpr,Ypr] = Res.Tran.backward([Xsrc Ysrc]);
            % convert Xpr,Ypr (pixel in reference catalog) to RA/Dec
            
            % Project catalog from sky to plan
            % input is radians
            % output is ~pixels

            [SrcRA,SrcDec] = imUtil.proj.gnomonic_inv(Xpr,Ypr,[Res.TranCenter.RA, Res.TranCenter.Dec]./RAD, RAD.*ARCSEC_DEG./Config.Proc.FitAstrom.Scale,'deg');
            