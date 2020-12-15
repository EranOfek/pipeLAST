function prep_images_visit(Date,varargin)
%
% Example: lastpipe.pipe.prep_images_visit(celestial.time.julday([15 9 2020]));


RAD = 180./pi;
ARCSEC_DEG = 3600;

if nargin<0
    Date = [];
end
if isempty(Date)
    % get date of today
    JD = celestial.time.julday; % UTC now   
else
    % assume Date is in some JD format
    JD = Date;       
end






InPar = inputParser;
addOptional(InPar,'FlatType',{'Flat','SkyFlat','DomeFlat'});
addOptional(InPar,'Config_node','config.node_1.txt');
addOptional(InPar,'Config_camera','config.camera_1_1_1.txt');
addOptional(InPar,'Config_mount','config.mount_1_1.txt');
addOptional(InPar,'Config_proc','config.proc_1.txt');
addOptional(InPar,'Config_background','config.proc-background1_1.txt');
addOptional(InPar,'Config_sources','config.proc-find_sources1_1.txt');
addOptional(InPar,'Config_FitAstrom','config.proc-fit_astrometry1_1.txt');


addOptional(InPar,'KeyExpTime','EXPTIME');
addOptional(InPar,'KeyTempDet','TEMP_DET');
addOptional(InPar,'KeyFilter','FILTER');
addOptional(InPar,'TempEdges',(-20:5:15)); % group temperature bins
addOptional(InPar,'MinNumberImages',5); % group temperature bins
addOptional(InPar,'SaveProd',{'Im','Var','PixFlag'});
addOptional(InPar,'SaveSub',true); % if provided, override configuration file
addOptional(InPar,'SubCCDSEC',[]); % if provided, override configuration file
addOptional(InPar,'SubUnCCDSEC',[]); % if provided, override configuration file
addOptional(InPar,'NewNoOverlap',[]); % if provided, override configuration file

addOptional(InPar,'SelectMethod','first');  % 'first' | 'last'
parse(InPar,varargin{:});
InPar = InPar.Results;

InPar.Date = celestial.time.julday([15 9 2020]);
InPar.Date = celestial.time.julday([16 9 2020]);

Config.Node            = lastpipe.util.read_config_file(InPar.Config_node);
Config.Camera          = lastpipe.util.read_config_file(InPar.Config_camera);
Config.Mount          = lastpipe.util.read_config_file(InPar.Config_mount);
Config.Proc            = lastpipe.util.read_config_file(InPar.Config_proc);
Config.Proc.Background = lastpipe.util.read_config_file(InPar.Config_background);
Config.Proc.Sources    = lastpipe.util.read_config_file(InPar.Config_sources);
Config.Proc.FitAstrom    = lastpipe.util.read_config_file(InPar.Config_FitAstrom);





if InPar.SaveSub
    if isempty(InPar.SubCCDSEC) || isempty(InPar.SubUnCCDSEC) || isempty(InPar.NewNoOverlap)

        [InPar.SubCCDSEC,InPar.SubUnCCDSEC,Center,Nxy,InPar.NewNoOverlap]=imUtil.image.subimage_grid(Config.Proc.CCDSEC([2 4]),...
                                            'SubSizeXY',Config.Proc.SubSizeXY,...
                                            'OverlapXY',Config.Proc.OverlapXY);
    end
else
    % don't save sub images
    InPar.SubCCDSEC   = [];
    InPar.SubUnCCDSEC = [];
end

% *_001.fits - marks images that didn't start processing
%   002.fits - ongoing processing
%   003.fits - a raw image for which the process was completed
FileNameTemplate = sprintf('%s*_001.fits',Config.Node.ProjName);

PWD = pwd;


%%
% upload Dark images 
% no need for var
% 1.8s for full image 'im','pixflag
% 2.6s for full image 'im','var','pixflag
% 4.7s for sub images, im','pixflag'

[~,~,Dark] = lastpipe.db.latest_calib_image('NeededJD',JD,...
                                            'DataBaseName','table',...
                                            'Type','dark',...
                                            'Config_camera',InPar.Config_camera,...
                                            'ExpTime',[],...
                                            'DetTempRange',[],...
                                            'MinNUM_COMB',Config.Proc.MinNUM_COMB,...
                                            'Field','0',...
                                            'Level','proc','SubLevel','n',...
                                            'Product',{'im','pixflag'});
                                        

% upload Flat images
% no need for var
[~,~,Flat] = lastpipe.db.latest_calib_image('NeededJD',JD,...
                                            'DataBaseName','table',...
                                            'Type','flat',...
                                            'Config_camera',InPar.Config_camera,...
                                            'ExpTime',[],...
                                            'DetTempRange',[],...
                                            'MinNUM_COMB',Config.Proc.MinNUM_COMB,...
                                            'Field','0',...
                                            'Level','proc','SubLevel','n',...
                                            'Product',{'im','pixflag'});

                                        
% PSF templates
PsfTemplate = Config.Proc.Sources.PsfFun(   Config.Proc.Sources.PsfFunPar{:});                        
                                        
% transformation object
Tran = Config.Proc.Tran(Config.Proc.TranPar);
Tran.symPoly;


% while NotStop
Nsub              = size(InPar.SubCCDSEC,1); % number of sub images
ContinueReduction = true;
Iim               = 0;   % counter of image in field
Field             = NaN;
AllImages         = imCl(Config.Proc.MaxNumImagesVisit,Nsub);
while ContinueReduction
    % check if a new image has arrived and it is not locked
    % In order to lock an image change its verion in the file name from 1
    % to 2
    PathRaw=imUtil.util.file.construct_path('Date',Date,'TimeZone',Config.Node.TimeZone,'Level','raw',...
                                     'DataDir',Config.Camera.DataDir,...
                                     'Base',Config.Camera.BaseDir);
                        
    
    
    [FileName,Prop,FieldNew,FieldReq,Image]=lastpipe.util.select_image_for_reduction('Path',PathRaw,...
                                                            'Config_node',Config.Node,...
                                                            'Config_proc',Config.Proc,...
                                                            'Field',Field,...
                                                            'LockImage',true,...
                                                            'Pause',1,...
                                                            'TimeOutCycles',30);
                                                           
    
    
    if isempty(FileName)
        % no file found
        
        
    else
        Field = FieldNew;
        
        % trim image
        Image = trim(Image,Config.Proc.CCDSEC,'ccdsec');
        
        % subtract Dark
        Image.Im           = Image.Im - Dark.Im;
        % copy mask from dark
        Image.PixFlag      = Dark.PixFlag;
        
        % divide by flat
        Image.Im           = Image.Im./Flat.Im;
        % combine Flat mask
        Image.PixFlag.Mask = bitor(Image.PixFlag.Mask,Flat.PixFlag.Mask);
        
        % mask saturated pixels
        Image = flag_saturatedPix(Image,Config.Camera.DefaultSaturation,'Saturated');
        
        NewVisit = false;  % a flag indicating if a new visit started
        
        if FieldReq==FieldNew
            % same field
        else
            % new field
            Iim = 0;
            NewVisit = true;
        end
        Iim = Iim + 1;    
        if Iim>Config.Proc.MaxNumImagesVisit
            Iim = 1;
            NewVisit = true;
        end
        
        if NewVisit
            if ~isempty(AllImages(1,1).Im)
                % a new vist started
                % clean all stuff related to previous visit
                % save all data

                NewVisit = false;
            end
        end
        
        
        % break the image to sub images:
        if isempty(InPar.SubCCDSEC)
            InPar.SubCCDSEC = ccdsec(Image);
            AllImages(Iim) = Image;
        else
            % break image
            AllImages(Iim,:) = trim(Image,InPar.SubCCDSEC,'ccdsec','NOCCDSEC',InPar.NewNoOverlap);
        end
            
        
        tic;
        % for each sub image (starting with the center)
        KeyValBack      = imUtil.util.struct2keyval(Config.Proc.Background);
        KeyValSources   = imUtil.util.struct2keyval(Config.Proc.Sources);
        KeyValFitAstrom = imUtil.util.struct2keyval(Config.Proc.FitAstrom);
        for Isub=1:1:Nsub    
            Isub
            % estimate background and variance (scalar)
            
            [AllImages(Iim,Isub).Back,AllImages(Iim,Isub).Var] = imUtil.background.background(AllImages(Iim,Isub).Im,KeyValBack{:});
                                                               
            % source finding
            [AllImages(Iim,Isub).Cat]=imUtil.sources.find_sources(AllImages(Iim,Isub).Im, KeyValSources{:},...
                                                                  'BackIm',AllImages(Iim,Isub).Back,...
                                                                  'VarIm',AllImages(Iim,Isub).Var,...
                                                                  'Psf',PsfTemplate);
            
            % flag overlap
            AllImages(Iim,Isub) = flag_edge(AllImages(Iim,Isub),'CCDSEC',InPar.NewNoOverlap(Isub,:),'FlagName','Overlap');
            % flag edge
            AllImages(Iim,Isub) = flag_edge(AllImages(Iim,Isub),'CCDSEC',Config.Proc.NearEdgeDist,'FlagName','NearEdge');
                        
            % find CR
            FlagCR = imUtil.sources.find_crHT(AllImages(Iim,Isub).Cat,'SN_1','SN_2',Config.Proc.DetectionThresholdCR);
            
            % Flag CR in image
            Tmp = get_col(AllImages(Iim,Isub).Cat,{'XPEAK','YPEAK'});
            %XY_CR = Tmp{1}(FlagCR,:);
          
            AllImages(Iim,Isub).PixFlag = set_bit_coo(AllImages(Iim,Isub).PixFlag,'CR_FilterDeltaBeforeSub',Tmp(FlagCR,:));
            
            % propagte Mask to catalog
            
            
        end
            toc
            'a'
            
        for Isub=1:1:Nsub
            % astrometry
            % get approximate RA/Dec of camera center:
            RA     = getVal(AllImages(Iim,Isub).Header,'RA');
            RA     = RA{1};
            Dec    = getVal(AllImages(Iim,Isub).Header,'DEC');
            Dec    = Dec{1};
            % approximate RA/Dec of subimage center
            Xcenter = Config.Proc.CCDSEC(2).*0.5;
            Ycenter = Config.Proc.CCDSEC(4).*0.5;
            
            [SubRA,SubDec]=lastpipe.util.subimage_coo(RA,Dec,Xcenter,Ycenter, InPar.SubCCDSEC(Isub,:), Config.Proc.FitAstrom.Scale, Config.Proc.FitAstrom.Flip,0)
            
            
            
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
            
            % add RA, Dec to catalog
            AllImages(Iim,Isub).Cat = add_col(AllImages(Iim,Isub).Cat, [SrcRA, SrcDec],[1 2],{'RA','Dec'},{'deg','deg'});
            
            


            
            %semilogy(Res.Resid.RefMag(Res.Resid.FlagSrc),Res.Resid.Resid(Res.Resid.FlagSrc),'.')
            W = tran2dCl2wcsCl(Res.Tran,'TranCenter',Res.TranCenter)
            
        end
            
            % propagate mask into source catalog

            

            % astrometry
            %   estimate position of sub image based on header - of WCS
            %       exist use it, if not use header
            %   if first sub image
            %       upload reference catalog
            %   end
            %   if FieldSolved
            %       run_astrometry_with_known_position
            %   else
            %       run_astrometry_with_unknown_position
            %       Add Counter +1 to number of field solved
            %   end
            %   if counter>X declare FieldSolved=true

            % write astrometric solution to header

            % propagate astrometry to catalog

            % set the flasg of the image: ImFlag

            % save data products: proc image, mask, catalog
        % end
    end % numel(Files)==0
end  % while ContinueReduction


cd(PWD);