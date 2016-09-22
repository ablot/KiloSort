% default options are in parenthesis after the comment

addpath(genpath('/home/blota/Matlab/KiloSort')) % path to kilosort folder
addpath(genpath('/home/blota/Matlab/npy-matlab')) % path to npy-matlab scripts


% Directory to process
sRootDir =  '/mnt/ssd/Shohei/processed_data/datfiles/';
%sExpName = 'ephys11_2016-08-19_21-13-12_block17_kwd_101_rec0_shkshk0';
sLogFile =  '/mnt/ssd/Shohei/processed_data/logkilo_shk_32ch.csv';
sFilter = 'shkshk'; % will cluster only exp with that in their name
nNumChans = 32;
bTetrode = false; %for display only, should I put channels 4 by line


stDirRoot = dir(sRootDir);
for nFileNum = 1:numel(stDirRoot)
    sFileName = stDirRoot(nFileNum).name;
    
    if length(sFileName)< 3 || isempty(strfind(sFileName, sFilter))
        continue
    end
    disp(['Doing  ' sFileName])
    fileID = fopen(sLogFile, 'a');
    fprintf(fileID,'%s\n', sFileName);
    fclose(fileID);
    
    try
        
        ops = create_config(sRootDir, sFileName, sLogFile, sFilter, nNumChans);
        
        fprintf('Doing %s\n', sFileName)
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
    catch ME
        fileID = fopen(sLogFile, 'a');
        fprintf(fileID,', !!! Error while doing %s !!!\n', sFileName);
        fclose(fileID);
        disp(['    Error while doing ', sFileName])
        disp(ME.identifier)
    end
end
