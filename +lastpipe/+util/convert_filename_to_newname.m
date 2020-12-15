function convert_filename_to_newname
%%
% Example: lastpipe.util.convert_filename_to_newname



%<ProjName>.<TelescopeID>_YYYYMMDD.HHMMSS.FFF_<filter>_<FieldID>_<type>_<level>.<sub level>_<Product>_<version>.<FileType>
Files = dir('LAST*.fits');
Nfile = numel(Files);
for Ifile=1:1:Nfile
    OldName = Files(Ifile).name;
    
    Split = regexp(OldName,'_','split');
    
    ProjName = Split{1};
    Date     = Split{2};
    Filter   = Split{3};
    FieldID  = '9999';
    SpSp     = regexp(Split{5},'\.','split');
    Type     = SpSp{1};
    Level    = 'raw.n';
    Product  = 'im';
    Version  = '001';
    FileType = 'fits';
    
    FileName = sprintf('%s_%s_%s_%s_%s_%s_%s_%s.%s',ProjName,...
                           Date,...
                           Filter,...
                           FieldID,...
                           Type,...
                           Level,...
                           Product,...
                           Version,...
                           FileType);
   
    movefile(OldName,FileName);
end
                       
