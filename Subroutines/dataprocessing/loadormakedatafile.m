function [Data_final, Model] = loadormakedatafile(Model,layercounts,Runtype)

%% [Data_final, Model] = loadormakedatafile(Model,layercounts,Runtype)
% Load and/or preprocess selected impurity records from ice core. 
% Preprocessing is done according to Model.preprocessing(:,1). Preprocessed 
% data is saved. If Runtype.reuse='no', preprocessing is done from scratch, 
% otherwise preprocessed data may be loaded from prior runs. Layercounts 
% are only used for plotting, and may be given as an empty array. 
% The following changes are made to Model structure array: 
% - If using analytical values for derivnoise, 'analytical' is replaced by 
%   actual values. 
% - If missing data series: These are removed from Model array, including 
%   their corresponding preprocessing steps etc. 
% Copyright (C) 2015  Mai Winstrup

%% Flag is an indicator of missing impurity records:
flag = nan(1,Model.nSpecies);

%% Final depth scale:
Data_final.depth(:,1) = Model.dstart+Model.dx_center*Model.dx:Model.dx:...
    Model.dend+Model.dx_center*Model.dx;
% Initialize data array:
Data_final.data = nan(length(Data_final.depth),Model.derivatives.nDeriv+1,...
    Model.nSpecies);

% Initialize figures:
if Runtype.plotlevel>0
    hfigpreproc = gobjects(Model.nSpecies,1);
    hfigderiv = gobjects(Model.nSpecies,1);
end

%% Load/preprocess the individual data records:
for j = 1:Model.nSpecies

    %% Output folder for preprocessed data:
    outputdir = makepreprocfolder(Model.icecore,Model.species{j},...
        Model.preprocess{j,1},Model.dx,Runtype);
    
    %% Does processed data exist? 
    % If so, these are loaded provided Runtype.reuse='yes'
    if strcmp(Runtype.reuse,'yes') 
        % List existing datafiles with similar resolution and preprocessing:
        listing = dir([outputdir '/*m.mat']);

        % Removing those not covering the appropriate depth interval:
        N = size(listing,1);
        if N>0
            d1 = zeros(1,N);
            d2 = zeros(1,N);
            for i = 1:N
                index1 = strfind(listing(i,1).name,'-');
                index2 = strfind(listing(i,1).name,'m');
                d1(i) = str2double(listing(i,1).name(1:index1-1));
                d2(i) = str2double(listing(i,1).name(index1+1:index2-1));
            end
            mask = d1<=Model.dstart & d2>=Model.dend;
            listing = listing(mask,:);
        
            % Load the smallest file (if file exist):
            if size(listing,1)>0
                [~,imin]=min([listing.bytes]);
                filename = listing(imin,1).name;
                load([outputdir '/' filename]);
        
                % Remove excess data from outside interval:
                mask = depth>=Model.dstart+Model.dx_center*Model.dx & ...
                    depth<=Model.dend+Model.dx_center*Model.dx;
                depth = depth(mask);
                
                % Check that depth scale is correct, i.e. that data is 
                % computed with correct value of dx_center. If not, data 
                % will be re-preprocessed to correct depth scale.
                if ismember(depth(1),Data_final.depth)
                    % Add to output data file:
                    % Place data correctly in array (since data may not 
                    % cover entire interval):
                    index = interp1(Data_final.depth,...
                        1:length(Data_final.depth),depth,'nearest');
                    
                    % Are all required derivatives calculated?
                    if Model.derivatives.nDeriv+1 <= size(data,2)
                        Data_final.data(index,1:Model.derivatives.nDeriv+1,j) = ...
                            data(mask,1:Model.derivatives.nDeriv+1);
                    else
                        % Otherwise, calculate derivatives:
                        [slope,derivnoise] = calculateslope(data(mask,1),...
                            Model.derivatives.nDeriv,Model.derivatives.slopeorder,...
                            Model.derivatives.slopedist,0);
                        Data_final.data(index,1:Model.derivatives.nDeriv+1,j) = ...
                            [data(mask,1),slope];
                    end
                    
                    % Display warning if data series does not cover all of 
                    % interval (some flexibility in interval endpoints)
                    if index(1)>10 || index(end)<length(Data_final.depth)-10
                        disp(['OBS: ' Model.species{j} ' only covers interval ' ...
                            num2str(depth(1)-Model.dx_center*Model.dx) '-' ...
                            num2str(depth(end)-Model.dx_center*Model.dx) 'm.'])
                    end
                
                    % Test for only NaNs in data series 
                    if sum(isfinite(Data_final.data(:,1,j)))==0; 
                        flag(j) = 1; % Data are nan in all of current interval 
                        disp([Model.species{j} ' not available for current depth interval'])
                    end
                
                    % Also loaded are the analytically-derived relative 
                    % white noise weighting values for the derivative data 
                    % series. If appropriate, these are added to the Model 
                    % structure array. 
                    if strcmp(Model.derivnoise,'analytical')
                       Model.derivnoise = derivnoise(1:Model.derivatives.nDeriv+1);
                    end
                
                    % And we're done! 
                    % Proceed to next impurity record.
                    continue
                else
                    clear data depth
                end
            end
        end
    end

    %% Otherwise: Load and preprocess the raw data for current interval
    rawdata = loadrawdata(Model.species{j},Model.path2data); 
    % Format of rawdata:
    % rawdata(:,1): Depth
    % rawdata(:,2): Data
    
    %% If no data exists in interval:
    % This may happen in two situations:
    % a) The data record does not exist in data file. 
    % b) Data record exists, but has no data in interval.

    % Impurity species does not exist in data file: 
    % Set flag, display error message, and go to next impurity species.
    if isempty(rawdata); 
        flag(j) = 2; 
        disp([Model.species{j} ' does not exist in data file']);
        continue
    end
    
    % Does data exist in at least part of data interval?   
    % If not, set flag, display error message, and continue to next 
    % impurity species.
    mask = rawdata(:,1)>=Model.dstart+Model.dx_center*Model.dx & ...
        rawdata(:,1)<=Model.dend+Model.dx_center*Model.dx;
    if sum(isfinite(rawdata(mask,2)))==0; 
        % Data is nan in all of current interval: 
        flag(j) = 1; 
        disp([Model.species{j} ' not available for current depth interval']); 
        continue 
    end
    
    %% Remove data from outside interval, while keeping some extra data 
    % around edges. 
    % Amount of additional data depends on preprocessing distance:
    if isempty(Model.preprocess{j,1}) || size(Model.preprocess{j,1},2)==1 
        L = 0;
    elseif isempty(Model.preprocess{j,1}{:,2}); % empty placeholder
        L = 0;
    else
        L = cell2mat(Model.preprocess{j,1}(:,2));
    end
    mask = rawdata(:,1)>=Model.dstart-L & rawdata(:,1)<=Model.dend+L;
    depth = rawdata(mask,1);
    data0 = rawdata(mask,2);
    
    %% Preprocess data, downsample, and calculate derivatives:
    % If Model.dx is empty, the original resolution is kept.
    [data, depth, derivnoise, hfigpreproc(j), hfigderiv(j)] = ...
        makedatafile(data0,depth,Model.preprocess(j,1),Model.derivatives,...
        Model.dx,Model.dx_center,Runtype.plotlevel,Model.species(j),layercounts);
    
    %% Remove extra data from edges: 
    mask = depth>=Model.dstart+Model.dx_center*Model.dx & ...
        depth<=Model.dend+Model.dx_center*Model.dx;
    depth = depth(mask);
    data = data(mask,:);
    
    %% Save data:
    filename = [num2str(Model.dstart) '-'  num2str(Model.dend) 'm'];
    save([outputdir '/' filename '.mat'],'data','depth','derivnoise');
    % Interval depths in name of data file reflect the interval in 
    % consideration for layer counting, and do not necessarily correspond 
    % to the actual depth interval covered by the data (which may be 
    % smaller). 
    
    %% Save example of data:
    if Runtype.plotlevel>0
        if ~isempty(Model.preprocess{j,1})
            figure(hfigpreproc(j))
            print([outputdir '/' filename '_data.jpeg'],'-djpeg','-r300')
        end

        figure(hfigderiv(j));
        print([outputdir '/' filename '_deriv.jpeg'],'-djpeg','-r300')
    end
    
    %% Include in data array containing data for all species:
    % Place data correctly in array:
    index = interp1(Data_final.depth,1:length(Data_final.depth),depth,'nearest');
    Data_final.data(index,:,j) = data; 
    
    % Display warning if data series does not cover all of interval (some 
    % flexibility in interval endpoints)
    if index(1)>10 || index(end)<length(Data_final.depth)-10
        disp(['OBS: ' Model.species{j} ' only covers interval ' ...
            num2str(depth(1)-Model.dx_center*Model.dx) '-' ...
            num2str(depth(end)-Model.dx_center*Model.dx) 'm.'])
    end
    
    %% Add analytical weighting values to Model (if wanted):
    if strcmp(Model.derivnoise,'analytical')
        Model.derivnoise = derivnoise;
    end
end

%% Remove unavailable data records from consideration for annual layer 
% detection:
mask = isfinite(flag);
nFlag = sum(mask);
if nFlag>0
    Data_final.data(:,:,mask) = []; % Remove data in array
    Model.species = Model.species(~mask); % Remove name of species 
    Model.nSpecies = length(Model.species); % New total number of species
    Model.preprocess = Model.preprocess(~mask,:); % Remove from preprocessing
    Model.wSpecies = Model.wSpecies(~mask); % Remove from weighting
end

%% And (maybe) close figures:
if Runtype.plotlevel==1
    close(hfigpreproc(isgraphics(hfigpreproc,'figure'))); 
    close(hfigderiv(isgraphics(hfigpreproc,'figure')));
end
end

function outputdir = makepreprocfolder(icecore,species,preprocess,dx,Runtype)
%% outputdir = makepreprocfolder(icecore,species,preprocess,dx,Runtype)
% This function creates a foldername corresponding to a specific 
% preprocessed data series. The folder is created if it doesn't already 
% exist. 

%% Running in development mode?
if strcmp(Runtype.develop,'yes'); outputdir = './Output/develop';
else outputdir = './Output';
end

%% Including the (ordered) preprocessing steps:
preprocname = [];
for i = 1:size(preprocess,1)
    % Numeric values (distances etc.) used in preprocessing:
    if size(preprocess,2)==1
        dists = [];
    else
        numval = preprocess{i,2};
        % Convert to string:
        dists = [];
        for k=1:length(numval); dists = [num2str(numval) '-']; end
        dists = dists(1:end-1);
    end
    % Append to filename:
    preprocname = [preprocname preprocess{i} dists '_'];
end
preprocname = preprocname(1:end-1);

%% Add resolution of data file:
% Number of significant digits:
if dx>=10^-2; 
    res = [num2str(dx*100) 'cm'];
else res = [num2str(dx*10^3) 'mm'];
end
if isempty(preprocname); preprocname = ['none_' res];
else preprocname = [preprocname '_' res];
end

%% Output folder for processed data:
outputdir = [outputdir '/' icecore '/ProcessedData/' species '/' preprocname];

%% Make directory:
if ~exist(outputdir,'dir')
    mkdir(outputdir)
end
end