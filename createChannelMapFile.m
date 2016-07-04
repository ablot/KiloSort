function [sChannelMapFileName] = createChannelMapFile(nNumChannels, sRootPath)

connected = ones(nNumChannels, 1);
chanMap   = 1:nNumChannels;
chanMap0ind = chanMap - 1;

xcoords   = repmat([1 2 3 4]', 1, nNumChannels/4);
xcoords   = xcoords(:);
ycoords   = repmat(1:nNumChannels/4, 4, 1);
ycoords   = ycoords(:);
kcoords   = ones(nNumChannels,1); % grouping of channels (i.e. tetrode groups)

sChannelMapFileName = fullfile(sRootPath, 'chanMap.mat');
save(sChannelMapFileName, 'chanMap','connected', 'xcoords', ...
        'ycoords', 'kcoords', 'chanMap0ind')
end