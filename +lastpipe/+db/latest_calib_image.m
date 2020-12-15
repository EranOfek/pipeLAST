function [OutFiles,TableDB,OutIm]=latest_calib_image(DataBaseName,varargin)
% get the path and name of the latest calibration image
% Package: +lastpipe.db
% Description: Look for latest calibration images (Dark or Flat) in the
%              local database.
% Input  : * Parisr of key,val. Options are:
%            'DataBaseName' - Database name. Default is 'table'.
%            'Config_camera' - Camera configuration file name.
%                       Default is 'config.camera_1_1_1.txt'.
%            'NeededJD' - Needed JD. Default is cirrent UTC JD:
%                       celestial.time.julday.
%            'ExpTime' - Needed Exposure Time. Default is 15.
%            'DetTempRange' - Detector temperature range. If empty, then
%                       ignore. Default is [].
%            'MinNUM_COMB' - Minimum number of combined images used to
%                       produce the product. Default is 5.
%            'Field' - Field name. If '0' - will return '0' field (i.e.,
%                       the full image). If 'sub' will return all the sub
%                       images (i.e., field '0.*').
%            'Type' - Image type. Default is 'dark'.
%            'Level' - Image level. Default is 'proc'.
%            'SubLevel' - Image sub level. Default is 'n'.
%            'Product' -  - Image products.
%                       Default is {'im','var','pixflag'}.
%            'KeyExpTime' - Default is 'EXPTIME'.
%            'KeyTempDet' - Default is 'TEMP_DET'.
%            'KeyNUM_COMB' - Default is 'NUM_COMB'.
%            'KeyField' - Default is 'Field'.
%            'KeyType' - Default is 'Type'.
%            'KeyLevel' - Default is 'Level'.
%            'KeySubLevel' - Default is 'SubLevel'.
%            'KeyProduct' - Default is 'Product'.
%            'KeyVersion' - Default is 'Version'.
%            'KeyJD' - Default is 'JD'.
% Output : - A structure arry of selected images names and path
%          - Table of the entire DB.
%          - An imCl object containing the requested images.
% Example: [Out,TableDB,OutIm]=lastpipe.db.latest_calib_image('DataBaseName','table','Type','flat')




InPar = inputParser;
addOptional(InPar,'DataBaseName','table');
addOptional(InPar,'Config_camera','config.camera_1_1_1.txt');
addOptional(InPar,'NeededJD',celestial.time.julday);
addOptional(InPar,'ExpTime',15);
addOptional(InPar,'DetTempRange',[]);
addOptional(InPar,'MinNUM_COMB',5);
addOptional(InPar,'Field','0');  % or 'sub'
addOptional(InPar,'Type','dark');
addOptional(InPar,'Level','proc');
addOptional(InPar,'SubLevel','n');
addOptional(InPar,'Product',{'im','var','pixflag'});
addOptional(InPar,'KeyExpTime','EXPTIME');
addOptional(InPar,'KeyTempDet','TEMP_DET');
addOptional(InPar,'KeyNUM_COMB','NUM_COMB');
addOptional(InPar,'KeyField','Field');
addOptional(InPar,'KeyType','Type');
addOptional(InPar,'KeyLevel','Level');
addOptional(InPar,'KeySubLevel','SubLevel');
addOptional(InPar,'KeyProduct','Product');
addOptional(InPar,'KeyVersion','Version');
addOptional(InPar,'KeyJD','JD');

parse(InPar,varargin{:});
InPar = InPar.Results;

if ~iscell(InPar.Product)
    InPar.Product = {InPar.Product};
end
Nprod = numel(InPar.Product);

switch lower(InPar.DataBaseName)
    case 'table'
        PWD = pwd;
        
        if isstruct(InPar.Config_camera)
            Config.Camera = InPar.Config_camera;
        else
            Config.Camera      = lastpipe.util.read_config_file(InPar.Config_camera);
        end
        cd(Config.Camera.BaseDir);
        

        switch lower(InPar.Type)
            case 'dark'
                Created = lastpipe.util.cdmkdir(Config.Camera.DarkDBDir);
                DBname  = Config.Camera.DarkDB;
            case 'flat'
                Created = lastpipe.util.cdmkdir(Config.Camera.FlatDBDir);
                DBname  = Config.Camera.FlatDB;
                % do not use exposure time for Flat selection
                InPar.ExpTime = [];
                % do not use DetTemp for Flat selection
                InPar.DetTempRange = [];
            otherwise
                error('Unknown table/Type name');
        end
        TableDB = imUtil.util.file.load2(DBname);      
        Ntable  = size(TableDB,1);
        
        % select based on parameters
        if isempty(InPar.ExpTime)
            FlagExp = true(Ntable,1);
        else
            FlagExp = TableDB.(InPar.KeyExpTime) == InPar.ExpTime;
        end
        if isempty(InPar.DetTempRange)
            FlagTemp = true(Ntable,1);
        else
            FlagTemp = TableDB.(InPar.KeyTempDet)>=min(InPar.DetTempRange) & TableDB.(InPar.KeyTempDet)<=max(InPar.DetTempRange);
        end
        
        % regular expression on Field
        switch lower(InPar.Field)
            case '0'
                % full image requested
                FlagField = strcmp(TableDB.(InPar.KeyField),'0');
            case 'sub'
                % all sub image requested
                FlagField = ~Util.cell.isempty_cell(regexp(TableDB.(InPar.KeyField),'0\.\d+','match'));
                
            otherwise
                % exact field name is requested
                FlagField = strcmp(TableDB.(InPar.KeyField),InPar.Field);
        end
        
        
        Flag = FlagExp & FlagTemp & FlagField & ...
               TableDB.(InPar.KeyNUM_COMB)>=InPar.MinNUM_COMB & ...
               strcmp(TableDB.(InPar.KeyType),InPar.Type) & ...
               strcmp(TableDB.(InPar.KeyLevel),InPar.Level) & ...
               strcmp(TableDB.(InPar.KeySubLevel),InPar.SubLevel);
           
        if sum(Flag)==0
            error('No %s images',InPar.Type);
        end
        Ind = find(Flag);
        
        ListJD     = TableDB.(InPar.KeyJD)(Ind);
        [~,MinIJD] = min(abs(ListJD - InPar.NeededJD));
        NearestJD  = ListJD(MinIJD);

        IndM = find(TableDB.(InPar.KeyJD)(Ind)==NearestJD);
        Ind  = Ind(IndM);

        TableVersion = str2double(TableDB.(InPar.KeyVersion));
        [MaxVersion] = max(TableVersion(Ind) );
        IndV = find((TableVersion(Ind) == MaxVersion));
        Ind = Ind(IndV);

        % go over all products
        UniqueField = unique(TableDB.Field(Ind));
        Nfield = numel(UniqueField);
        
        for Ifield=1:1:Nfield
            % search all images associated with the field
            IndF = find(strcmp(TableDB.Field(Ind),UniqueField{Ifield}));
            II = Ind(IndF);
            Nii = numel(II);
            for Iii=1:1:Nii
                I = II(Iii);
                Prod = TableDB.(InPar.KeyProduct){I};
                
                OutFiles(Ifield).(Prod).FileName = TableDB.FileName{I};
                OutFiles(Ifield).(Prod).Path     = TableDB.Path{I};
                OutFiles(Ifield).(Prod).FullName = sprintf('%s%s',OutFiles(Ifield).(Prod).Path,OutFiles(Ifield).(Prod).FileName);
            end
            
        end
        
        
    case 'dark.table'
        
        PWD = pwd;
        
        if isstruct(InPar.Config_camera)
            Config.Camera = InPar.Config_camera;
        else
            Config.Camera      = lastpipe.util.read_config_file(InPar.Config_camera);
        end
        
        cd(Config.Camera.BaseDir);
   
        
        
        
        Created = lastpipe.util.cdmkdir(Config.Camera.DarkDBDir);
        
%         if Created
%             error('dark.table image doesnot exist');
%         end
        
        DBname  = Config.Camera.DarkDB;

        TableDB = imUtil.util.file.load2(DBname);
        
        
        for Iprod=1:1:Nprod
            Flag = TableDB.(InPar.KeyExpTime) == InPar.ExpTime & ...
                   TableDB.(InPar.KeyNUM_COMB)>=InPar.MinNUM_COMB & ...
                   strcmp(TableDB.(InPar.KeyField),InPar.Field) & ...
                   strcmp(TableDB.(InPar.KeyType),InPar.Type) & ...
                   strcmp(TableDB.(InPar.KeyLevel),InPar.Level) & ...
                   strcmp(TableDB.(InPar.KeySubLevel),InPar.SubLevel) & ...
                   strcmp(TableDB.(InPar.KeyProduct),InPar.Product{Iprod});
               
            if sum(Flag)==0
                error('No dark images');
            else
                Ind = find(Flag);
                
                ListJD     = TableDB.(InPar.KeyJD)(Ind);
                [~,MinIJD] = min(abs(ListJD - InPar.NeededJD));
                NearestJD  = ListJD(MinIJD);
                
                IndM = find(TableDB.(InPar.KeyJD)(Ind)==NearestJD);
                Ind  = Ind(IndM);
                
                [MaxVersion,IndV] = max(str2double(TableDB.(InPar.KeyVersion)(Ind) ));
                Ind = Ind(IndV);
                
                if numel(Ind)>1
                    error('conflicting entries in darkDB');
                end
                if numel(Ind)==0
                    error('Requested product was not found');
                end
                
                OutFiles(Iprod).Product  = InPar.Product{Iprod};
                OutFiles(Iprod).FileName = TableDB.FileName{Ind};
                OutFiles(Iprod).Path     = TableDB.Path{Ind};
                OutFiles(Iprod).FullName = sprintf('%s%s',OutFiles(Iprod).Path,OutFiles(Iprod).FileName);
                
            end
        end
        
        
        
        cd(PWD);
            
            
        
        
    case 'dark.sql'
    case 'flat.sql'
    case 'raw.sql'
    case 'proc.sql'
        
    otherwise
        error('Unknown DataBaseName option');
end



if nargout>2
    % upload the images
    
    Nout  = numel(OutFiles);
    OutIm = imCl(Nout,1);

    for Iout=1:1:Nout
        % create master dark/flat image:
        FN = fieldnames(OutFiles(Iout));
        
        OutIm(Iout) = imCl.fits2imCl(OutFiles(Iout).im.FullName,1);
        if any(strcmp(lower(FN),'back'))
            OutIm(Iout) = imCl.fits2imCl(OutFiles(Iout).back.FullName,1,'Add2imCl',OutIm(Iout),'Field','Back','ReadHead',false);
        end
        if any(strcmp(lower(FN),'var'))
            OutIm(Iout) = imCl.fits2imCl(OutFiles(Iout).var.FullName,1,'Add2imCl',OutIm(Iout),'Field','Var','ReadHead',false);
        end
        if any(strcmp(lower(FN),'pixflag'))
            OutIm(Iout) = imCl.fits2imCl(OutFiles(Iout).pixflag.FullName,1,'Add2imCl',OutIm(Iout),'Field','PixFlag','ReadHead',false,'Convert2Class',@uint32);
        end
            
    end
    
end

