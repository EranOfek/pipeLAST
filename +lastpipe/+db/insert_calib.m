function insert_calib(Type,FileCell,PathCell,ExpTimeCell,Stat,varargin)
% Insert dark images to local bias db



InPar = inputParser;
addOptional(InPar,'DarkDB',[]);
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


Config.Camera      = lastpipe.util.read_config_file(InPar.Config_camera);

Config.Node        = lastpipe.util.read_config_file(InPar.Config_node);
Config.Proc        = lastpipe.util.read_config_file(InPar.Config_proc);
Config.Proc.isdark = lastpipe.util.read_config_file(InPar.Config_isdark);
Config.Proc.dark   = lastpipe.util.read_config_file(InPar.Config_dark);


PWD = pwd;
cd(Config.Camera.BaseDir);

switch Type
    case 'dark'
        Dir = Config.Camera.DarkDBDir;
        DB  = Config.Camera.DarkDB;
    case 'flat'
        Dir = Config.Camera.FlatDBDir;
        DB  = Config.Camera.FlatDB;
    otherwise
        error('Unknown Type option');
end

lastpipe.util.cdmkdir(Dir);


load(DB);

% write new lines to DB
Nline = numel(FileCell);
for Iline=1:1:Nline
    AddDB.FileName = FileCell{I};
    AddDB.Path     = PathCell{I};
    AddDB.ExpTime  = ExpTimeCell{I};
end


%https://dev.mysql.com/downloads/file/?id=494003
%sudo dpkg -i mysql-apt-config_0.8.15-1_all.deb
% https://www.mathworks.com/help/database/ug/mysql-jdbc-linux.html
