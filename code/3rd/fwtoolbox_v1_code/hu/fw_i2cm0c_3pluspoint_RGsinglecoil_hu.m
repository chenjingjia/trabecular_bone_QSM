
%% *************************************************************************
% REGION GROWING (RG) fieldmap algorithm for water-fat chemical shift 
% decomposition.  Algorithm performs water-fat decomposition with NO
% R2* correction.
%
% FOR EDUCATIONAL AND DEMONSTRATION PURPOSES.
% NOT RECOMMENDED FOR LARGE DATA SET RECONSTRUCTIONS !!!
%% *************************************************************************
% Based on the algorithms described by 
%   Yu, et al. MRM 2005 54:1032-1039 
%   Reeder, et al. MRM 2004 51:35-45
%%
%% *************************************************************************
% THIS ALGORITHM HAS BEEN WRITTEN IN BASIC MATLAB SYNTAX FOR TEACHING
% PURPOSES.  IT IS NOT OPTIMIZED FOR SPEED.  THE PROGRAM IS INTERACTIVE.
%% *************************************************************************
%
%% *************************************************************************
% INPUT: imDataParams and algoParams structures (examples)
    % imDataParams.images [Nx Ny Nz Ncoils NTE]
    % imDataParams.TE = TE values in (seconds)
    % imDataParams.FieldStrength in (Tesla)
    % imDataParams.PrecessionisClockwise (0 or 1)

    %algoParams.reg_grow=1;    % 0 - No (voxel independent), 1 - Yes (RG)
    %algoParams.rg=[15 15];    % entry 1: number of super pixels               
                          % entry 2: extrapolation / region growing kernel size ...
                          % weighting neighborhood

    %algoParams.downsize=[16 16];% downsample size of low res image to start RG
    %algoParams.filtsize=[7 7];  % median filter size for final smoothing of fieldmap
    %algoParams.maxiter=300;     % maximum number of IDEAL iterations before loop break
    %algoParams.fm_epsilon=1;    % in IDEAL iteration, the fm error tolerance (Hz)
    %algoParams.sp_mp=1;         % single fat peak (0) or multi fat peak (1)
                            %% *************************************************************************
                            % SPECTRAL MODEL
                            %% *************************************************************************
    %algoParams.M = 2;% Number of species; 2 = fat/water 
    %algoParams.species(1).name = 'water';
    %algoParams.species(1).frequency=0; 
    %algoParams.species(1).relAmps=1;
    %algoParams.species(1).name = 'fat';
    %algoParams.species(2).frequency=-[3.8 3.4 2.6 1.94 0.39 -0.6]; % positive fat frequency --> -2*pi*fieldmap*te effect
    %algoParams.species(2).relAmps=[0.087 0.693 0.128 0.004 0.039 0.048];

% OUTPUT: matfile of output structure
    % outParams.water, also outParams.species(1).amps
    % outParams.fat, also outParams.species(2).amps
    % outParams.fieldmap (Hz)
%% *************************************************************************
%                     ---> FOR SINGLE COIL ONLY <--- 
% ---> (multi-coil datasets will be coil-combined before processing)<--- 
% 
% by H. Harry Hu (houchunh@usc.edu)
% last modified, February 14, 2012 for Diego Hernando's Matlab Toolbox
%% *************************************************************************


function outputParams = fw_i2cm0c_3pluspoint_RGsinglecoil_hu( imDataParams, algoParams )

%% *************************************************************************
% BEGIN PROGRAM
%% *************************************************************************
% $$$ clc; clear all; close all;
% $$$ format compact;
warning ('off','all');

% ADD PATH
% $$$ [BASEPATH,~]=fileparts(mfilename('fullpath'));
% $$$ tmp = BASEPATH; addpath(tmp); 
% $$$ fprintf('Adding to Path: %s\n',tmp); clear tmp;
% $$$ tmp = fullfile(BASEPATH,'Support Functions'); addpath(tmp); 
% $$$ fprintf('Adding to path: %s\n',tmp); clear tmp;
% $$$ tmp = fullfile(BASEPATH,'Data'); addpath(tmp); 
% $$$ fprintf('Adding to path: %s\n',tmp); clear tmp;

%% *************************************************************************
% LOAD DATA
%% *************************************************************************
% $$$ load_data;

% load PKdata2.mat;
% clear temp*;
% temp = exist ('imDataParams','var');
% if (temp == 0)
%     clear imDataParams;
%     imDataParams = data;
%     clear data;
% end
% clear temp*;

% *************************************************************************
% USER ADJUSTABLE CONSTANTS
% NOTE TO SELF - PROBABLY SHOULD MAKE A GUI FOR USER ADJUSTABLE CONSTANTS
% *************************************************************************
% RG VARIABLES - see Yu, et al. MRM 2005 54:1032-1039 for details
% $$$ 
% $$$ algoParams.reg_grow=1;    % 0 - No (voxel independent), 1 - Yes (RG)
% $$$ algoParams.rg=[15 15];    % entry 1: number of super pixels               
% $$$                           % entry 2: extrapolation / region growing kernel size ...
% $$$                           % weighting neighborhood
% $$$                           
% $$$ algoParams.downsize=[16 16];% downsample size of low res image to start RG
% $$$ algoParams.filtsize=[7 7];  % median filter size for final smoothing of fieldmap
% $$$ algoParams.maxiter=300;     % maximum number of IDEAL iterations before loop break
% $$$ algoParams.fm_epsilon=1;    % in IDEAL iteration, the fm error tolerance (Hz)
% $$$ algoParams.sp_mp=1;         % single fat peak (0) or multi fat peak (1)

%% *************************************************************************
% MISCELLANEOUS CONSTANTS
%% *************************************************************************
algoParams.te = imDataParams.TE;
[Nx Ny Nz Nc N]=size(imDataParams.images);
algoParams.N = N;
algoParams.Precession = imDataParams.PrecessionIsClockwise;


%% DH*: Combine multiple coils 
if Nc > 1
  imDataParams.images = coilCombine3D( imDataParams.images );
  Nc = 1;
end


if algoParams.Precession <= 0 % DH* made this <=0 (instead of ==1) to (hopefully!) comply with rest of toolbox
                              %     fat_ppm = -fat_ppm;
  imDataParams.images = conj(imDataParams.images);
  disp('Precession <= 0');
end
validity_checks;



% $$$ %% *************************************************************************
% $$$ % SPECTRAL MODEL
% $$$ %% *************************************************************************
% $$$ algoParams.M = 2;% Number of species; 2 = fat/water
% $$$ % water
% $$$ algoParams.species(1).name = 'water';
% $$$ algoParams.species(1).frequency=0; 
% $$$ algoParams.species(1).relAmp=1;
% $$$ 
% $$$ % fat
% $$$ algoParams.species(2).name = 'fat';
% $$$ 
% $$$ if algoParams.sp_mp==1    
% $$$     % NOTE THIS IS THE DIFFERENCE IN PPM BETWEEN FAT AND WATER, NOT THE
% $$$     % ACTUAL FAT PPMs
% $$$     
% $$$     fat_ppm=[3.8 3.4 2.6 1.94 0.39 -0.6]; % positive fat frequency --> -2*pi*fieldmap*te effect
% $$$     algoParams.species(2).relAmp=[0.087 0.693 0.128 0.004 0.039 0.048];
% $$$ else
% $$$     fat_ppm=3.4;
% $$$     algoParams.species(2).relAmp=1;
% $$$ end

% acetone
%       fat_ppm=2.8;
%       algoParams.species(2).relAmp=1;    

algoParams.species(2).frequency=(algoParams.species(2).frequency - algoParams.species(1).frequency).*4258*imDataParams.FieldStrength*1e-2; %% DH* to make code compatible with toolbox


%% *************************************************************************
% COEFFICIENT MATRIX A
%% *************************************************************************
[algoParams.A algoParams.C algoParams.D] = solveA(algoParams);
algoParams.Ainv = (transpose(algoParams.A)*algoParams.A) \ transpose(algoParams.A);
% $$$ plot_fatpeaks;
clear imDataParams;

%% *********************************************************************
% DOWNSAMPLE DATA FOR LOW RESOLUTION FIELDMAP ESTIMATION
%% *********************************************************************
[newNx,newNy,Nz,data,datafull,BW,BWfull,xrat,yrat]=getlowresdata(datafull,algoParams);

%% *************************************************************************
% IMPLEMENT IDEAL
%% *************************************************************************
if algoParams.reg_grow == 1     
    disp ('Entering IDEAL of Low Res Data...');
    fm_hold = run_ideal(algoParams,newNx,newNy,Nz,BW,data);
    % fm_hold is the initial fieldmap estimate from low res data.
    tic
    disp ('Entering REGION GROWING Loop...');
    fm_estimate = regiongrowloop(algoParams,Nx,Ny,Nz,xrat,yrat,data,datafull,BW,BWfull,fm_hold);
    % fm_estimate is the region grown fieldmap estimate.        
    fprintf('\n\n');
    toc
else
    % VOXEL INDEPENDENT
    disp ('Entering IDEAL Voxel Independent (VI)');
    fprintf ('\nVI IDEAL can cause sever water-fat swap errors, especially if strong B0 inhomogeneity is anticipated.');
    fm_estimate = run_ideal(algoParams,Nx,Ny,Nz,BWfull,datafull);    
end

%% *************************************************************************
% FINAL WF DECOMPOSITION
%% *************************************************************************

outputParams = final_wf_decomp(algoParams,Nx,Ny,Nz,algoParams.filtsize,datafull,BWfull,fm_estimate);

outputParams.species(1).amps = outputParams.water;
outputParams.species(1).name = 'water';

outputParams.species(2).amps = outputParams.fat;
outputParams.species(2).name = 'fat';

% $$$ water = outputParams.water;
% $$$ fat = outputParams.fat;
% $$$ fieldmap = outputParams.fieldmap;

% $$$ save output.mat water fat fieldmap;
% $$$ close all;
% $$$ fprintf ('\n --> DONE <-- \n');

% if algoParams.reg_grow==1
%     plottrajectory;
% end