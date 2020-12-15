function prep_master_dark(varargin)
% Prepare master dark images
% Package: +lastpipe.pipe
% Description: Given a date in which dark images were taken, locate the
%              directory in which the images are stored (using 
%              imUtil.util.file.construct_path) and read the dark images.
%              For each exposure time available, and for each detector
%              temperature in some range, create a master dark image.
%              The images are store in the calib/ directory for this
%              spsecific date.
%              The function is writing several types of images to the disk.
%              First it saves the full detector images, and it saves the
%              sub images. Second it saves, a dark image, a dark-variance 
%              image and a pixel-based bit-mask image.
% Input  : * * Pairs of ...,key,val,... arguments. Following
%            keywords are available:
%            'Date' - A JD (date) at which the dark images were obtained.
%            'Config_node' - Node configuration file (in search path)
%                   Default is 'config.node_1.txt'.
%            'Config_camera' - Camera configuration file.
%                   Default is 'config.camera_1_1_1.txt'.
%            'Config_proc' - Processing configuration file.
%                   Default is 'config.proc_1.txt'.
%            'Config_isdark' - Configuration file for the isdark method.
%                   Default is 'config.proc-isdark_1.txt'.
%            'Config_dark' - Configuration file for the dark method.
%                   Default is 'config.proc-dark_1.txt'.
%            'KeyExpTime' - Exposure time header keyword.
%                   Default is 'EXPTIME'.
%            'KeyTempDet' - Detector temperature header keyword.
%                   Default is 'TEMP_DET'.
%            'KeyFilter' - Filter header keyword.
%                   Default is 'FILTER'.
%            'TempEdges' - A vector of tempearture edges. These are the
%                   boundries that define tempearture bins in which to
%                   aggregate dark images.
%                   Default is (-20:5:15).
%            'MinNumberImages' - Minimum number of images to combine.
%                   Default is 5.
%            'SaveProd' - Cell array of imCl products to save.
%                   Default is {'Im','Var','PixFlag'}.
%            'SaveSub' - Save sub images. Default is true.
%            -- The following three kewords defines the boundries of the
%            sub images. These are the output of imUtil.image.subimage_grid
%            'SubCCDSEC' - If empty will generate using the information in the
%                   config files. Default is empty.
%            'SubUnCCDSEC' - If empty will generate using the information in the
%                   config files. Default is empty.
%            'NewNoOverlap' - If empty will generate using the information in the
%                   config files. Default is empty.
% Output : null
%     By : Eran O. Ofek                   Oct 2020
% Example: lastpipe.pipe.prep_master_dark('Date',celestial.time.julday([15 9 2020]))

InPar = inputParser;
addOptional(InPar,'Date',[]);
addOptional(InPar,'Config_node','config.node_1.txt');
addOptional(InPar,'Config_camera','config.camera_1_1_1.txt');
addOptional(InPar,'Config_proc','config.proc_1.txt');
addOptional(InPar,'Config_isdark','config.proc-isdark_1.txt');
addOptional(InPar,'Config_dark','config.proc-dark_1.txt');
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
parse(InPar,varargin{:});
InPar = InPar.Results;

%InPar.Date = celestial.time.julday([15 9 2020]);

Config.Node        = lastpipe.util.read_config_file(InPar.Config_node);
Config.Camera      = lastpipe.util.read_config_file(InPar.Config_camera);
Config.Proc        = lastpipe.util.read_config_file(InPar.Config_proc);
Config.Proc.isdark = lastpipe.util.read_config_file(InPar.Config_isdark);
Config.Proc.dark   = lastpipe.util.read_config_file(InPar.Config_dark);


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

   

%% read image names 'Type','dark',...
PathRaw=imUtil.util.file.construct_path('Date',InPar.Date,'TimeZone',Config.Node.TimeZone,'Level','raw',...
                                     'DataDir',Config.Camera.DataDir,...
                                     'Base',Config.Camera.BaseDir);
                        



PWD = pwd;
%% dark prep

% read template files
if ~isempty(Config.Proc.isdark.DarkTemplate)
    % read DarkTemplate file
    IC = imCl.fits2imCl(Config.Proc.isdark.DarkTemplate);
    Config.Proc.isdark.DarkTemplate = IC.Im;
end
if ~isempty(Config.Proc.isdark.DarkTemplate)
    % read DarkTemplate file
    IC = imCl.fits2imCl(Config.Proc.isdark.DarkVarTemplate);
    Config.Proc.isdark.DarkVarTemplate = IC.Var;
end

% read all dark images available in directory
cd(PathRaw);
FileName = sprintf('%s*_Dark*.%s',Config.Node.ProjName, Config.Proc.ImageFileType);
List     = imUtil.util.filelist(FileName);

% read headers only
H = headCl.fits2headCl(List);

% read ExpTime and detector temperature from headers and convert to vectors
ExpTime    = cell2mat(getVal(H,InPar.KeyExpTime));
TempDet    = cell2mat(getVal(H,InPar.KeyTempDet));
FilterCell = getVal(H,InPar.KeyFilter);
if isnan(FilterCell{1})
    Filter = Config.Camera.Filter;
else
    Filter = FilterCell{1};
end

% select unique exposure times
UniqueExpTime  = unique(ExpTime);
NuniqueExpTime = numel(UniqueExpTime);

Ntemp          = numel(InPar.TempEdges)-1;

for Iun=1:1:NuniqueExpTime
    % for each unique exposure time
    % image with the specific ExpTime
    FlagExpTime = UniqueExpTime(Iun)==ExpTime;
    
    % the detector temperature for the curent exposure time
    TempDetPerExpT = TempDet(FlagExpTime);
    
    % group images according to temperature range
    for Itemp=1:1:Ntemp
        FlagTemp = TempDetPerExpT>InPar.TempEdges(Itemp) & TempDetPerExpT<InPar.TempEdges(Itemp+1);
        if sum(FlagTemp)>=InPar.MinNumberImages
            % selected images
            FlagImages = TempDet>InPar.TempEdges(Itemp) & TempDet<InPar.TempEdges(Itemp+1) & FlagExpTime;
           
            DetTempList = TempDetPerExpT(FlagImages);
            MeanDetTemp = mean(DetTempList);
            
            
            % read FITS images into imCl object
            IC = imCl.fits2imCl(List(FlagImages));
            
            % trim images (remove overscan)
            IC = trim(IC,Config.Proc.CCDSEC,'ccdsec');
            
            
            

            [IsDark,Res]=isdark(IC,'Gain',Config.Proc.Gain,...
                                   'ReadNoise',Config.Proc.ReadNoise,...
                                   'DarkCurrent',Config.Proc.DarkCurrent,...
                                   'FileNameKey','dark',...
                                   'NoiseThreshold',Config.Proc.isdark.NoiseThreshold,...
                                   'DarkTemplate',Config.Proc.isdark.DarkTemplate,...
                                   'DarkVarTemplate',Config.Proc.isdark.DarkVarTemplate);

            % prep dark
            KeyVal = imUtil.util.struct2keyval(Config.Proc.dark);
            [Dark,ResStat]=bias(IC(IsDark),'IsBiasFun',[],KeyVal{:});

            % save dark image
            % get time
            JD = IC.Header.julday;
            JD = cell2mat(JD);
            MidJD = mean(JD);
            
            % delete the Nim content in the dark image 
            % just to save memory
            Dark.Nim = [];
            
            % measure global statistics
            DarkSum = Dark.PixFlag.summary;
            Stat.NbitNot0   = DarkSum{1}.NpixNot0;
            Stat.medianIm   = median(Dark.Im(:));
            Stat.rstdVar    = imUtil.background.rstd(Dark.Var(:));
            Stat.medVar     = median(Dark.Var(:));
            
            IndBiasKeys = find(~Util.cell.isempty_cell(regexp(DarkSum{1}.KeyName,'Bias','match')));
            KeyNames  = DarkSum{1}.KeyName(IndBiasKeys);
            Nkey      = numel(KeyNames);
            for Ikey=1:1:Nkey
                ModifiedKey = regexprep(KeyNames{Ikey},'Bias_','D');
                Stat.(ModifiedKey) = DarkSum{1}.BitCount(IndBiasKeys(Ikey));
            end
            
            % add statistics to header
            Dark.Header=addKey(Dark.Header,Stat);       
            
            % store the full Dark images, including catalog
            AllNamesF=lastpipe.util.save_product(Dark,...
                            'Config_camera',Config.Camera,...
                            'Date',MidJD,...
                            'Fields',InPar.SaveProd,...
                            'Type','dark','Level','proc','SubLevel','n',...
                            'FieldID','0',...
                            'ProjName',Config.Node.ProjName,...
                            'TimeZone',Config.Node.TimeZone,...
                            'Filter',Filter,...
                            'DataDir',Config.Camera.DataDir,...
                            'BaseDir',Config.Camera.BaseDir,...
                            'HDU',1,...
                            'DataType',Config.Proc.DataType,...
                            'CatDataType',Config.Proc.CatDataType,...
                            'CatDataset',Config.Proc.CatalogFileDataset,...
                            'SubCCDSEC',[],...
                            'NewNoOverlap',[]);
                        
            % Store a sub-images version of the dark images
            if ~isempty(InPar.SubCCDSEC) && ~isempty(InPar.NewNoOverlap)
                AllNamesS=lastpipe.util.save_product(Dark,...
                                'Config_camera',Config.Camera,...
                                'Date',MidJD,...
                                'Fields',InPar.SaveProd,...
                                'Type','dark','Level','proc','SubLevel','n',...
                                'FieldID','0',...
                                'ProjName',Config.Node.ProjName,...
                                'TimeZone',Config.Node.TimeZone,...
                                'Filter',Filter,...
                                'DataDir',Config.Camera.DataDir,...
                                'BaseDir',Config.Camera.BaseDir,...
                                'HDU',1,...
                                'DataType',Config.Proc.DataType,...
                                'CatDataType',Config.Proc.CatDataType,...
                                'CatDataset',Config.Proc.CatalogFileDataset,...
                                'SubCCDSEC',InPar.SubCCDSEC,...
                                'NewNoOverlap',InPar.NewNoOverlap);
            end
            

            
            
            

        end
    end
end

cd(PWD);
