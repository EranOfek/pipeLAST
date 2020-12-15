function [FileName,Prop,FieldNew,FieldReq,Image]=select_image_for_reduction(varargin)
%
% Package: +lastpipe.util
% Description: This function checks the images directory for a new image of
%              a spefic field, and return the image name if exist.
% Input  : 
% Example: [FileName,Prop,FieldNew,FieldReq]=lastpipe.util.select_image_for_reduction;



InPar = inputParser;
addOptional(InPar,'Path',[]);  % directory to CD into
addOptional(InPar,'Config_node','config.node_1.txt');   % or a structure with the Config.Node 
addOptional(InPar,'Config_proc','config.proc_1.txt');
addOptional(InPar,'Field',NaN); % field ID or NaN if a new field is requested
addOptional(InPar,'LockImage',true); 
addOptional(InPar,'Pause',1);
addOptional(InPar,'TimeOutCycles',30); 
addOptional(InPar,'Type','science'); 
addOptional(InPar,'Level','raw.n'); 
addOptional(InPar,'Product','im'); 


parse(InPar,varargin{:});
InPar = InPar.Results;

% reading configuration file
if isstruct(InPar.Config_node)
    Config.Node = InPar.Config_node;
else
    Config.Node            = lastpipe.util.read_config_file(InPar.Config_node);
end

% reading configuration file
if isstruct(InPar.Config_proc)
    Config.Proc = InPar.Config_proc;
else
    Config.Proc            = lastpipe.util.read_config_file(InPar.Config_proc);
end


if ~isempty(InPar.Path)
    PWD = pwd;
    cd(InPar.Path);
end
    

% *_001.fits - marks images that didn't start processing
%   002.fits - ongoing processing
%   003.fits - a raw image for which the process was completed
FileNameTemplate = sprintf('%s*_%s_%s_%s_001.fits',Config.Node.ProjName,InPar.Type,InPar.Level,InPar.Product);
   
FieldReq = InPar.Field;

Files = dir(FileNameTemplate);
if ~isnan(InPar.Field)
    Prop = imUtil.util.file.filename2prop({Files.name},true);
    FlagField = [Prop.Field]==InPar.Field;
    
    if sum(FlagField)==0
        % Observations of the requested field were not found
        
        Continue = true;
        Counter = 0;
        while Continue
            Counter = Counter + 1;
            Files = dir(FileNameTemplate);
            Prop = imUtil.util.file.filename2prop({Files.name},true);
            FlagField = [Prop.Field]==InPar.Field;
    
            if Counter>InPar.TimeOutCycles
                Continue = false;
                
                if sum(FlagField)==0
                    % switch field
                    InPar.Field = NaN;
                    
                else
                    % field found
                    Files = Files(FlagField);
                end
            else
                if sum(FlagField)==0
                    % New image of the same field wasn't found
                    % try again
                else
                    % Image found
                    Continue = false;
                    Files = Files(FlagField);
                    
                end
                
            end
        end
    else
        % observations of the requested field were found
        Files = Files(FlagField);
       
    end
end

if isnan(InPar.Field)
    % select new field based on availability
    Files = dir(FileNameTemplate);
end

[~,Isel] = min([Files.datenum]);
if isempty(Isel)
    Files    = [];
    Prop     = [];
    FieldNew = NaN;
    Image    = [];
    
else
    
    FileName = Files(Isel).name;
    Prop     = imUtil.util.file.filename2prop(FileName,true);
    FieldNew = Prop.Field;


    if InPar.LockImage
        % lock the image
        % locking is done by modifing the image version to 002
        FileNameV2 = regexprep(FileName,'001.fits','002.fits');
        % how to ensure that there is no conflict with another process?
        movefile(FileName,FileNameV2);
    else
        FileNameV2 = FileName;
    end
    % image name is now stored in FileNameV2
    FileName = FileNameV2;

    if nargout>4
        % upload the image
        Image = imCl.fits2imCl(FileNameV2);
        % trim image
        Image = trim(Image,Config.Proc.CCDSEC,'ccdsec');
    end
end
        
if ~isempty(InPar.Path)
    cd(PWD);
end
    