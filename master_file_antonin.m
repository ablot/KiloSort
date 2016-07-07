% default options are in parenthesis after the comment

addpath(genpath('/home/blota/Matlab/KiloSort')) % path to kilosort folder
addpath(genpath('/home/blota/Matlab/npy-matlab')) % path to npy-matlab scripts

% Directory to process
sRootDir =  '/home/rgtm02-mic/Data/Antonin';
sLogFile =  '/home/rgtm02-mic/Data/Antonin/logkilo.csv';

fileID = fopen(sLogFile, 'w');
fprintf(fileID,'Starting log kilosort for %s\n', sRootDir);
fclose(fileID);

stDirRoot = dir(sRootDir);
for nFileNum = 1:numel(stDirRoot)
    sFileName = stDirRoot(nFileNum).name;
    if length(sFileName)< 3 || isempty(strfind(sFileName, 'shkshk'))
        continue
    end
    disp(['Doing  ' sFileName])
    fileID = fopen(sLogFile, 'a');
    fprintf(fileID,'   Doing %s', sFileName);
    fclose(fileID);
    
    try
    sRootPath = fullfile(sRootDir, sFileName);
    sDatFileName = [sFileName '.dat'];
    
    ops.GPU                 = 1; % whether to run this code on an Nvidia GPU (much faster, mexGPUall first)
    ops.verbose             = 1; % whether to print command line progress
    ops.showfigures         = 0; % whether to plot figures during optimization
    
    ops.datatype            = 'dat';  % binary ('dat', 'bin') or 'openEphys'
    ops.fbinary             = fullfile(sRootPath, sDatFileName); % will be created for 'openEphys'
    ops.fproc               = fullfile(sRootPath, 'temp_wh.dat'); % residual from RAM of preprocessed data
    ops.root                = fullfile(sRootPath); % 'openEphys' only: where raw files are
    
    ops.fs                  = 30000;        % sampling rate
    ops.NchanTOT            = 32;           % total number of channels
    ops.Nchan               = 32;           % number of active channels
    ops.Nfilt               = 32*2;           % number of filters to use (2-4 times more than Nchan, should be a multiple of 32)
    ops.nNeighPC            = 12; % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)
    ops.nNeigh              = 16; % visualization only (Phy): number of neighboring templates to retain projections of (16)
    
    % options for channel whitening
    ops.whitening           = 'full'; % type of whitening (default 'full', for 'noSpikes' set options for spike detection below)
    ops.nSkipCov            = 1; % compute whitening matrix from every N-th batch (1)
    ops.whiteningRange      = 32; % how many channels to whiten together (Inf for whole probe whitening, should be fine if Nchan<=32)
    
    % define the channel map as a filename (string) or simply an array
    [sChannelMapFileName] = createChannelMapFile(ops.NchanTOT, sRootPath); % create the map file
    ops.chanMap             = sChannelMapFileName; % make this file using createChannelMapFile.m
    % ops.chanMap = 1:ops.Nchan; % treated as linear probe if a chanMap file
    
    % other options for controlling the model and optimization
    ops.Nrank               = 3;    % matrix rank of spike template model (3)
    ops.nfullpasses         = 6;    % number of complete passes through data during optimization (6)
    ops.maxFR               = 20000;  % maximum number of spikes to extract per batch (20000)
    ops.fshigh              = 300;   % frequency for high pass filtering
    ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection
    ops.scaleproc           = 200;   % int16 scaling of whitened data
    ops.NT                  = 32*1024+ ops.ntbuff;% this is the batch size (try decreasing if out of memory)
    % for GPU should be multiple of 32 + ntbuff
    
    % the following options can improve/deteriorate results.
    % when multiple values are provided for an option, the first two are beginning and ending anneal values,
    % the third is the value used in the final pass.
    ops.Th               = [4 10 10];    % threshold for detecting spikes on template-filtered data ([6 12 12])
    ops.lam              = [5 20 20];   % large means amplitudes are forced around the mean ([10 30 30])
    ops.nannealpasses    = 4;            % should be less than nfullpasses (4)
    ops.momentum         = 1./[20 400];  % start with high momentum and anneal (1./[20 1000])
    ops.shuffle_clusters = 1;            % allow merges and splits during optimization (1)
    ops.mergeT           = .1;           % upper threshold for merging (.1)
    ops.splitT           = .1;           % lower threshold for splitting (.1)
    
    % options for initializing spikes from data
    ops.initialize      = 'no'; %'fromData' or 'no'
    ops.spkTh           = -6;      % spike threshold in standard deviations (4)
    ops.loc_range       = [3  1];  % ranges to detect peaks; plus/minus in time and channel ([3 1])
    ops.long_range      = [30  6]; % ranges to detect isolated peaks ([30 6])
    ops.maskMaxChannels = 5;       % how many channels to mask up/down ([5])
    ops.crit            = .65;     % upper criterion for discarding spike repeates (0.65)
    ops.nFiltMax        = 10000;   % maximum "unique" spikes to consider (10000)
    
    % load predefined principal components (visualization only (Phy): used for features)
    dd                  = load('PCspikes2.mat'); % you might want to recompute this from your own data
    ops.wPCA            = dd.Wi(:,1:7);   % PCs
    
    % options for posthoc merges (under construction)
    ops.fracse  = 0.1; % binning step along discriminant axis for posthoc merges (in units of sd)
    ops.epu     = Inf;
    
    ops.ForceMaxRAMforDat   = 20e9; % maximum RAM the algorithm will try to use; on Windows it will autodetect.
    
    %%
    tic; % start timer
    
   
    if strcmp(ops.datatype , 'openEphys')
        ops = convertOpenEphysToRawBInary(ops);  % convert data, only for OpenEphys
    end
    %
    [rez, DATA, uproj] = preprocessData(ops);
    
    if strcmp(ops.initialize, 'fromData')
        % do scaled kmeans to initialize the algorithm (not sure if functional yet for CPU)
        optimizePeaks(uproj);
    end
    %
    [rez] = fitTemplates(ops, rez, DATA);
    
    %
    % extracts final spike times (overlapping extraction)
    fullMPMU;
    
    % posthoc merge templates (under construction)
    %     rez = merge_posthoc2(rez);
    
    % save matlab results file
    save(fullfile(ops.root,  'rez.mat'), 'rez');
    
    % save python results file for Phy
    rezToPhy(rez, ops.root);
    
    % remove temporary file
    delete(ops.fproc);
    %
    fileID = fopen(sLogFile, 'a');
    fprintf(fileID,', done\n');
    fclose(fileID);
    catch ME
        fileID = fopen(sLogFile, 'a');
        fprintf(fileID,', !!! Error while doing %s !!!\n', sFileName);
        fclose(fileID);
        disp(['    Error while doing ', sFileName])
        disp(ME.identifier)
    end
end
