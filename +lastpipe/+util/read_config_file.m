function [Data,Unit]=read_config_file(ConfigFileNames,Format)
% Return configuration parameters for LAST node, mount, telescope
% Package: +lastpipe.util
% Input  : - A configuration file name to read.
%          - File format:
%            'txt'. Default.
%            'json'
% Example: Config=lastpipe.util.read_config_file('config.mount_1_1.txt');


if nargin<2
    Format = 'txt';
end


switch lower(Format)
    case 'txt'
        FID = fopen(ConfigFileNames,'r');
        LineInd = 0;

        while ~feof(FID)
            %LineInd = LineInd + 1;
            %LineInd

            Line      = fgetl(FID);
            if ~isempty(Line)
                if strcmp(Line(1),'#') || strcmp(Line(1),'%') || isempty(Util.string.spacedel(Line))
                    % comment/empty - ignore
                else

                    LineData  = regexp(Line,':','split');

                    % remove blanks
                    LineData{1} = Util.string.spacedel(LineData{1});
                    LineData{2} = strtrim(LineData{2});
                    LineData{3} = strtrim(LineData{3});

                    Val = str2double(LineData{2});
                    if isnan(Val)
                        if numel(LineData{2})>0
                            if strcmp(LineData{2}(1),'[') || strcmp(LineData{2}(1),'{') || strcmp(LineData{2}(1),'@')
                                % a matrix or vector
                                try
                                    Val = eval(LineData{2});
                                catch
                                    Val = LineData{2};
                                end
                                Data.(LineData{1}) = Val;

                            else
                                % save as string
                                Data.(LineData{1}) = LineData{2};
                            end
                        else
                            % save as string
                            Data.(LineData{1}) = LineData{2};
                        end
                    else
                        % save as number
                        Data.(LineData{1}) = Val;
                    end
                    Unit.(LineData{1}) = LineData{3};
                end
            end
        end

    otherwise
        error('Unsupported file format option');
end



% 
% 
% Def.Comm      = '~/config/comm.cfg';
% Def.Node      = '~/config/node.cfg';
% Def.Mount     = '~/config/mount.cfg';
% Def.Telescope = '~/config/telescope.cfg';
% Def.Proc      = '~/config/proc.cfg';
% 
% if nargin<5
%     Proc = [];
%     if nargin<4
%         Telescope = [];
%         if nargin<5
%             Mount = [];
%             if nargin<2
%                 Node = [];
%                 if nargin<1
%                     Comm = [];
%                 end
%             end
%         end
%     end
% end
% 
% if isempty(Comm)
%     Comm = Def.Comm;
% end
% if isempty(Node)
%     Node = Def.Node;
% end
% if isempty(Mount)
%     Node = Def.Mount;
% end
% if isempty(Telescope)
%     Node = Def.Telescope;
% end
% if isempty(Proc)
%     Node = Def.Proc;
% end
% 
% 
% % read data from confugration files
% if ischar(Comm)
%     % read communication configuration file
%     
% end
% 
% if ischar(Node)
%     % read node configuration file
%     
% end
% 
% if ischar(Mount)
%     % read mount configuration file
%     
% end
% 
% if ischar(Telescope)
%     % read telescope/camera configuration file
%     
% end
% 
% if ischar(Proc)
%     % read processing configuration file
%     
% end
% 
% 
% % defaults parameters
% 
% if isnan(Node)
%     Config.Node.ProjName = 'LAST';
% 
%     % Data directory
%     Config.Node.BaseDir = '/data/euler/archive/LAST/';
%     Config.Node.DataDir = '';
% 
%     % Time - ALl times are measured in UTC
%     Config.Node.TimeZone = 2;  % used only for defining time to switch dir name
% end
% 
% if isnan(Mount)
%     Config.Mount.Lon    = NaN;    % East longitude [deg]
%     Config.Mount.Lat    = NaN;    % North latitude [deg]
%     Config.Mount.Height = NaN;    % WGS84 Elevation [m]
%     
% end
% 
% if isnan(Telescope)
%     % Camera
%     Config.Telescope.Filter            = 'clear';
%     Config.Telescope.CamareType        = 'QHY600-PH';
%     % high read noise -high dynmacic range
%     Config.Telescope.CameraMode        = 'highRN';
%     Config.Telescope.Gain              = 0.77;
%     Config.Telescope.ReadNoise         = 3.5;
%     
%     Config.Telescope.DarkCurrent       = 1e-2;
% end
% 
% if isnan(Proc)
%    
%     Config.Proc.ImageFileType        = 'fits';
%     Config.Proc.CatalogFileType      = 'hdf5';
%     
%     % dark Configameters
%     % isdark
%     Config.Proc.Dark.isdark.VarianceThreshold         = 5;   % between predicted variance and measured variance
%     Config.Proc.Dark.isdark.DarkImageTemplate         = '';
%     Config.Proc.Dark.isdark.DarkVarianceTemplate      = '';
%     % bias
%     Config.Proc.Dark.dark.MeanFun              = 'wsigclip';
%     Config.Proc.Dark.dark.MeanFunPar           = {'MeanFun',@nanmean,'StdFun','rstd','Nsigma',[7 7],'MaxIter',2};
%     Config.Proc.Dark.dark.VarFun               = 'rvar';
%     Config.Proc.Dark.dark.VarFunPar            = {};
%     Config.Proc.Dark.dark.MeanFunFlag          = @nanmean;
%     Config.Proc.Dark.dark.StdFunFlag           = 'rstd';
%     Config.Proc.Dark.dark.ThresholdSigma       = 8;
%     Config.Proc.Dark.dark.Abs                  = true;
%     Config.Proc.Dark.dark.FlareFlagName        = 'Bias_Flaring';
%     Config.Proc.Dark.dark.FlareFracRange       = [0.1 1];
%     Config.Proc.Dark.dark.LowStdFlagName       = 'Bias_Noise0';
%     Config.Proc.Dark.dark.LowStdThresholdVal   = 0.1;
%     Config.Proc.Dark.dark.HighStdFlagName      = 'Bias_HighStd';
%     Config.Proc.Dark.dark.HighStdThresholdVal  = 30;
%     Config.Proc.Dark.dark.HighValFlagName      = 'Bias_HighVal';
%     Config.Proc.Dark.dark.FlagThresholdVal     = Inf;
%     Config.Proc.Dark.dark.AddHeader            = true;
%     
%             
%     
% end
% 
% 
% 
