% default options are in parenthesis after the comment

addpath(genpath('/home/blota/Matlab/KiloSort')) % path to kilosort folder
addpath(genpath('/home/blota/Matlab/npy-matlab')) % path to npy-matlab scripts

pathToYourConfigFile = '/home/blota/Matlab/KiloSort/configFiles'; % take from Github folder and put it somewhere else (together with the master_file)
run(fullfile(pathToYourConfigFile, 'AntoninConfig32Ch.m'))

tic; % start timer
%
if ops.GPU     
    gpuDevice(1); % initialize GPU (will erase any existing GPU arrays)
end

if strcmp(ops.datatype , 'openEphys')
   ops = convertOpenEphysToRawBInary(ops);  % convert data, only for OpenEphys
end
%
[rez, DATA, uproj] = preprocessData(ops); % preprocess data and extract spikes for initialization
rez = fitTemplates(ops, rez, DATA, uproj);  % fit templates iteratively
rez = fullMPMU(ops, rez, DATA);% extract final spike times (overlapping extraction)

% posthoc merge templates (under construction)
%     rez = merge_posthoc2(rez);

% save matlab results file
save(fullfile(ops.root,  'rez.mat'), 'rez', '-v7.3');

% save python results file for Phy
rezToPhy(rez, ops.root);

% remove temporary file
delete(ops.fproc);
%%
