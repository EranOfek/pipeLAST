function insert_image(DataBaseName,AllHeader,PathCell,FileCell,varargin)
% Insert image to database


InPar = inputParser;
addOptional(InPar,'Config_camera','config.camera_1_1_1.txt');
parse(InPar,varargin{:});
InPar = InPar.Results;

switch lower(DataBaseName)
    case {'dark.table','flat.table'}
        
        PWD = pwd;
        
        if isstruct(InPar.Config_camera)
            Config.Camera = InPar.Config_camera;
        else
            Config.Camera      = lastpipe.util.read_config_file(InPar.Config_camera);
        end

        % MIDJD, FullImage, Type, Level, SubLevl, Product, FieldID, NAXIS1, NAXIS2, EXPTIME, NUM_COMB, FullName
        
        KeysFromHead = {'MidJD','NbitNot0','NAXIS1','NAXIS2','EXPTIME','NUM_COMB','TEMP_DET'};
        Nkeys  = numel(KeysFromHead);
        if imCl.isimCl(AllHeader)
            KeyVal = AllHeader.Header.getVal(KeysFromHead);
        elseif headCl.isheadCl(AllHeader)
            KeyVal = AllHeader.getVal(KeysFromHead);
        else
            error('Unknown Header type : must be headCl or imCl object');
        end
        
        Nim = numel(AllHeader);
        Nfile = numel(FileCell);
        for Ifile=1:1:Nfile
            Prop(Ifile) = imUtil.util.file.filename2prop(FileCell{Ifile});
        end
        for Ifile=1:1:Nfile
            % read keywords from header
            Iimkey = min(Ifile,Nim);
            for Ikeys=1:1:Nkeys
                Prop(Ifile).(KeysFromHead{Ikeys}) = KeyVal{Iimkey}{Ikeys};
            end
            Prop(Ifile).FileName = FileCell{Ifile};
            Prop(Ifile).Path     = PathCell{Ifile};
        end
        
        switch lower(DataBaseName)
            case {'dark.table'}
                cd(Config.Camera.BaseDir);
                lastpipe.util.cdmkdir(Config.Camera.DarkDBDir);

                DBname  = Config.Camera.DarkDB;
            case {'flat.table'}
                cd(Config.Camera.BaseDir);
                lastpipe.util.cdmkdir(Config.Camera.FlatDBDir);

                DBname  = Config.Camera.FlatDB;
        end
                
                
        if exist(DBname,'file')==0
            % file doesn't exist
            TableDB = [struct2table(Prop)];
        else
            % db exist
            TableDB = imUtil.util.file.load2(DBname);
        
            TableDB = [TableDB; struct2table(Prop)];
        end
        save('-v7.3',DBname,'TableDB');
        
        cd(PWD);
        
            
        
        
    case 'dark.sql'
    case 'flat.sql'
    case 'raw.sql'
    case 'proc.sql'
        
    otherwise
        error('Unknown DataBaseName option');
end