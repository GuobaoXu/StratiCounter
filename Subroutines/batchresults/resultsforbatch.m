function [Result, Layer0_new, batchStart_new] = ...
    resultsforbatch(depth,FBprob,Layerpos,Layer0,d,pd,logb,meanLambda,...
    batchStart,dDxLambda,iIter,Model,Runtype)

%% [Result, Layer0_new, batchStart_new] = resultsforbatch(depth,FBprob,...
% Layerpos,Layer0,d,pd,logb,meanLambda,batchStart,dDxLambda,iIter,Model,Runtype)
% Calculate results for the current batch, and initial conditions for the
% next. 

% Output:
% batchStart_new: Start pixel for next batch
% Layer0_new.pos: Probability of where the next "layer0" is starting 
% Layer0_new.no: Layer number distribution at tau 
% Layer0_new.noDx, Layer0_new.noMarker: Same, for layer thickness intervals 
% and for marker horisons.  
% Result.LayerDist.d: depth scale
% Result.LayerDist.mode: mode of timescale
% Result.LayerDist.mean: mean of timescale
% Result.LayerDist.quantile: quantiles of timescale
% Result.Layerpos.fb: layer positions according to FB algorithm [m]
% Result.Layerpos.vit: layer positions according to Viterbi [m]
% Result.Layerpos.combined: a "best" set of layer boundaries
% Result.Lambda.ndist: Probability distribution of layers in section 
% Result.Lambda.d: ending depth of corresponding lambda sections
% Result.Marker.ndist: Probability distribution of layer numbers in section
% Result.Marker.d: Depth of corresponding marker horizons.
% Result.nIter: Final iteration number for batch

% Mai Winstrup
% 2014-20-10 15:22: Updated version

%% Select ending pixel for batch: 
% We only consider the first part of data sequence (i.e. to and including 
% pixel tau), as the annual layering in the last part can be better 
% estimated when also using the subsequent data.
% The pixel tau is selected as the first pixel after a very likely layer 
% boundary, for which we are sure to be out of the previous layer. 
% Also calculating the ending location of the layer previous to the one in 
% pixel tau. 
batchLength = size(FBprob.gamma,1);
[tau, postau] = findtau(FBprob,meanLambda,d,batchLength,Model,Runtype.plotlevel); % 2014-10-20 11:47
% Note: tau is included in both batches

% Use for initialization of next batch:
Layer0_new.pos = postau;
% Next batch starts at:
batchStart_new = batchStart+tau-1; %[pixel from start of data series]

%% Resulting layer number distribution along batch:
% This is calculated up to and including pixel tau.
[ntau, ntauTotal, LayerDist] = ...
    batchlayerdist(depth,FBprob,tau,Layer0,Model,Runtype.plotlevel); % 2014-10-20 11:49

% Save:
Layer0_new.no = ntauTotal;
Result.LayerDist = LayerDist;

%% The most likely layer boundaries:
% Converting to depth, and computing an optimal set of layer boundaries by 
% combining results from the Forward-Backward algorithm with the Viterbi
% approach.
% DET SIDSTE (layerpos.combined) ER IKKE RIGTIG SET IGENNEM. 
[LayerposDepth, layerpos_combined] = batchlayerpos(Layerpos,depth,...
    tau,Layer0,postau,ntau,d,pd,logb,Model,Runtype.plotlevel);
Result.Layerpos = LayerposDepth;

%% Mean layer thickness in batch:
% For batch: Mode and associated uncertainties
%Result.lambdaBatch = ...
%    calclambdafromdist(ntau,depth(tau)-depth(1),Model.prctile);

% Ogs� gemme ntau -> nye lambda v�rdier: m�ske er det enkelte batches som
% udregningen er forkert p�. 

% Layer number probability distributions for predetermined sections; these 
% are later to be used for calculating mean layer thickness:
for ix = 1:length(Model.dxLambda)
    % Layer number distributions within sections:
    [distSections,Layer0_new.noDx{ix},dSectionBounds] = layerdistsection(depth,FBprob,...
        dDxLambda{ix},Layer0.noDx{ix},tau,ntau,d,pd,logb,Runtype.plotlevel);
   
    % Save: 
    if ~isempty(distSections)
        Result.Lambda(ix).d = dSectionBounds; 
        Result.Lambda(ix).ndist = distSections;
    end
end

%% Marker horizons: 
% Layer number probability distributions for sections between marker
% horizons:
for ix = 1:length(Model.dMarker)
    % Layer number distributions within sections:
    [distMarker,Layer0_new.noMarker{ix},dMarkerBounds] = layerdistsection(depth,FBprob,...
        Model.dMarker{ix},Layer0.noMarker{ix},tau,ntau,d,pd,logb,Runtype.plotlevel);
   
    % Save: 
    Result.Marker(ix).d = dMarkerBounds; 
    Result.Marker(ix).ndist = distMarker;
end

%% Number of iterations performed:
% Final iteration number: 
Result.nIter = iIter;