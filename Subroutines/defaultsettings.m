function Model = defaultsettings()

%% defaultsettings():
% Provide default settings for HMM layer detection algorithm.
% Mai Winstrup, 2014

%% Data files:
Model.icecore = '';
% Data existing for core:
Model.species = '';
Model.nSpecies = 0; 

% Weighting of various species:
Model.wSpecies = ones(Model.nSpecies,1);

%% Depth interval [m]:
Model.dstart = [];
Model.dend = []; 

%% Marker horizons to be used as tiepoints?
% No tiepoints:
Model.tiepoints = [];
% With tiepoints:
% Model.tiepoints(:,1) = []; % Depth [m]
% Model.tiepoints(:,2) = []; % Corresponding age
% Model.ageUnitTiepoints = ''; % Age unit of tiepoints
% Options: AD, BP, b2k, layers

%% Data treatment:
% Resolution of data series to be used in HMM Model:
mpx = 10^-3;
Model.dx = mpx; % [m/px]
% If Model.dx is empty: No interpolation to equidistant depthscale. 
% The resolution is allowed to (slowly) change with depth. 
% If using e.g. the midpoints of dx intervals:
Model.dx_center = 0*mpx;

% Preprocessing of each data series:
Model.preprocess{1:Model.nSpecies} = {'none',[]};
% Possible preprocessing steps:
% - No preprocessing ('none',[])
% - Linear interpolation over NaNs in data ('interpNaNs',[]);
% - Log-transformation ('log',[])
% - Box-Cox transformation ('boxcox', [lambda, (alpha)])
% - Normalization using quantiles ('quantile', Lwindow)
% - Normalization using min-max ('minmax', Lwindow)
% - Normalization using standard deviation ('zscore',Lwindow)
% - Using CDF-transform ('cdftransform',Lwindow)
% - Subtract constant ('minusconst',const)
% - Subtract mean ('minusmean')
% - Subtract baseline ('minusbaseline',[Lwindow, quantile])
% - Subtract smooth curve calculated using running average ('minussmooth', Lwindow)
% - Smooth using running average ('smooth',Lwindow)
% Window lengths are given in m. Inset [] if no window is required.

% Using data series itself and (possibly) its derivatives: 
Model.deriv = [0 1];
% Calculation of slope and curvature by Savitsky-Golay:
%if sum(Model.deriv)>0
    Model.slopeorder = [1 2]; % 0 corresponds to ordinary differencing
    Model.slopedist = [3 5]; % Window size (in number of observations)
%end

%% Length of each data batch (in approximate number of layers):
Model.nLayerBatch = 50; 
% If tiepoints are given, the length of each data batch corresponds to the
% interval between these. 

%% If using manual counts for initialization:
Model.manCountsName = 'Manual layer counts';
Model.pathManualCounts = '';
Model.ageUnitManual = '';

% depth interval used for determining these:
Model.manualtemplates = []; %[Model.dstart Model.dend];
% Perhaps set "[]" if using a sinusoidal shape instead (not implemented).

%% The annual layer model: 
% Calculation of the emission probabilities (b).
Model.type = 'PCA';
Model.order = 1;
% Normalizing each layer individually before calculating probabilities? (and shapes)
Model.normalizelayer = 'minusmean'; 
% Options: 
% 'none', 'minmax', 'zscore', 'minusmean'

% Using polynomial approximations to principal components of order:
Model.pcPolOrder = 5;

% Method for calculating the probabilities:
Model.bcalc = 'BLR'; % Bayesian Linear Regression
% Possible options (to be made available)
% 'BLR', 'BLR_wNaN', 'physical', 'hierachy', 'fourier'

% Timestep used for up/downsampling layers to stack:
Model.dtstack = 1/64; %[year]

% Number of layer shape iterations:
% Per batch:
Model.nTemplateBatch = 1; 
% For complete data set:
Model.nTemplateFull = 1;
% If 1: Layer shapes are based on manual counts
% If > 1: Layer shapes are based on autocounts from previous counting. 

%% Calculation of p(d):
% Type of layer thickness distribution:
Model.durationDist = 'logn';
% Definition and treatment of tails of distribution:
Model.tailType = 'evenly'; % Preferred: Evenly
Model.tailPrc = 0.5; % Percent removed from each tail. 

% Weighting of b relative to p(d):
Model.bweight = 1;
% Number of species and derivatives are accounted for automatically. 
% A value of Model.bweight>1: The dependency on layer shapes are 
% enhanced relative to layer durations. 

%% Initial model parameters and variation allowed:
% The initial set of layer parameters will be based on manual layer counts.
% Depth interval used to estimate these:
Model.initialpar = []; %[Model.dstart, Model.dstart+0.5*(Model.dend-Model.dstart)];
% Using the first half of data.

% Using the entire parameter covariance matrix?
Model.covariance = 'none'; 
% Options: 
% 'none': All layer Model parameters are considered uncorrelated.
% 'species': Layer parameters for a specific species is considered 
% correlated, but parameters for individual species are uncorrelated.
% 'full': Both inter- and intra-species correlation is taken into account.

% Entries in noise weighting matrix (W), giving the relative white noise 
% level of derivative data series:
Model.wWhiteNoise = 'analytical';
% Options: 
% 'analytical': Analytical values are used. 
% 'manual': Values based on the manual counting are used. 
% The value of wWhiteNoise can also be ascribed specific numbers. 

%% Iterations and convergence:
% Maximum number of iterations per batch:
Model.nIter = 4;

% Limit for convergence of EM-algorithm: 
Model.eps = -1; 
% If negative, the model will run exactly nIter iterations

% Parameters allowed to be updated at each iteration:
% The ordering is: 
% 1: my, 2: sigma (mode and variace of layer thickness distribution)
% 3: par, 4: cov, 5: nvar (layer shape mean parameters, inter-annual 
% covariance and white noise component)
Model.update = {'ML', 'ML', 'ML', 'ML', 'ML'}; 
% Options:
% 'none': No updates (i.e. maintained as initialpar)
% 'ML': Maximum-Likelihood updates

% Forgetting parameter in QB updates:
%if sum(Model.update==2)>0
%    Model.rho = 0.8;
%end

%% Combining batches: 
% Interval before end of batch in which the last layer boundary is found:
Model.batchOverlap = 5; % Measured in units of mean layer thicknesses

%% Output of algorithm:
% Percentiles for confidence intervals:
Model.confInterval = [50 95]; 

% Also computing results based on the Viterbi algorithm?
Model.viterbi = 'no';

% Interval(s) for determining average layer thicknesses:
% Regular length intervals:
Model.dxLambda = [0.5 1 5]; % [m]
% If empty, lambda values are not determined.

% Specific depth sections for mean layer thickness calculations:
Model.dMarker = [];

% Which timescale terminology to be used for output? 
Model.ageUnitOut = 'layers';
% Options: AD, BP, b2k, layers