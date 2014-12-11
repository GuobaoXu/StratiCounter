function Prior_new = updatepriors(Prior_old,Layerpar_new,Model)
    
%% Prior_new = updatepriors(Prior_old,Layerpar_new,Model)
% Update priors as prescribed in Model.update.

% Mai Winstrup,
% 2014-07-23 20:07: First independent version
% 2014-10-20 16:05: Model.update changed

%% Layer thickness parameters:
Prior_new.m = Layerpar_new.my;
if strcmp(Model.update(1),'QB')
    Prior_new.v = Prior_old.v; 
    disp('Using a Prior with constant variance for my')
    % Or:
    %Prior_new.v = Prior.v*Model.rho*par_new.sigma^2/(Prior.v*sumeta+Model.rho*par_new.sigma^2);
else
    Prior_new.v = [];
end
Prior_new.sigma = Layerpar_new.sigma;

%% Layer shape parameters:
Prior_new.u = Layerpar_new.par;
if strcmp(Model.update(3),'QB')
    Prior_new.invU = Prior_old.invU; 
    disp('Using a Prior with constant variance for u') 
    %Or:
    % Prior_new.invU = XWX_rhonvarinvU; 
else
    Prior_new.invU = [];
end    
Prior_new.cov = Layerpar_new.cov;
Prior_new.nvar = Layerpar_new.nvar;