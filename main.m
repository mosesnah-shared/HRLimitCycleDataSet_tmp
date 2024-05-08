% [Title]     KUKA-MIT Collaboration
% [Update]    At 2024.05.08
% [Description] 
%    - A brief script to use Imitation Learning for rhythmic movemnents
%      Details in the following references
%      [1] Saveriano, Matteo, et al. "Dynamic movement primitives in robotics: A tutorial survey." The International Journal of Robotics Research 42.13 (2023): 1133-1184.
%      [2] Nah, Moses C., Johannes Lachner, and Neville Hogan. "Robot Control based on Motor Primitives--A Comparison of Two Approaches." arXiv preprint arXiv:2310.18771 (2023).
%% (--) Initialization
clear; close all; clc;
addpath( 'DMPmodules' )

%% (1-) Main Script
%% (--) (1A) Data Pre-processing

% Load one of the .mat file under matlab_data
file_name = 'heart';
load( [ 'matlab_data/', file_name, '.mat' ] );

% Data has position and velocity, but we also need
% acceleration data for Imitation Learning of rhythmic DMP
% Section 2.2 of Ref. [1] 

% Hence, better to use the dataset with longest pos.
% For the `heart.mat` example, the longest dataset is the first one
 p_raw = data( 1 ).pos; 

% Plotting the XY position of the data
f = figure( ); a = axes( 'parent', f );
subplot( 1, 2, 1 ); hold on; 
plot(  p_raw( 1, : ) ); plot( p_raw( 2, : ) );

% We need to trim out the dataset that results in a closed loop
% Manually finding out the indexes which start and end at similar location
idx1 = 42; idx2 = 123;

% The trimmed out dataset and append the final data point for repeatability
 p_data =  p_raw( :, idx1:idx2 );  p_data( :, end+1 ) =  p_data( :, 1 ); 

% Offset added to start at (0,0)
p_data = p_data - p_data( :, 1 );

subplot( 1, 2, 2 ); hold on; 
plot(  p_data( 1, : ) ); plot( p_data( 2, : ) );

% Define the timestep dt to define the period
dt = 0.1;
Tp = dt * length( p_data );
t_data = ( 0:length( p_data )-1 ) * dt;

% Based on this timestep dt, define the velocity, acceleration by time
% discretization. Note that there are better ways to do this.
dp_data  = diff(  p_data, 1, 2 )/dt;  dp_data( :, end+1 ) =  dp_data( :, 1 );
ddp_data = diff( dp_data, 1, 2 )/dt; ddp_data( :, end+1 ) = ddp_data( :, 1 );

%% (--) (1B) Conducting Imitation Learning
tau_d   = Tp/(2*pi);        % d subscript for demo
alpha_z = 200.0;            % gain 1 of the transformation system
beta_z  = 0.25 * alpha_z;   % gain 2 of the transformation system
N = 50;                     % Number of basis functions
P = length( p_data );       % Number of data points

% The three elements that comprise the DMP
cs        = CanonicalSystem( 'rhythmic', tau_d, 1.0 );      % Canonical System
fs        = NonlinearForcingTerm( cs, N );                  % Nonlinear Forcing Term
trans_sys = TransformationSystem( alpha_z, beta_z, cs );    % Transformation System

% Calculating the required Nonlinear Forcing Term
% Goal location is zero 
g_d = mean( p_data, 2 );
B = trans_sys.get_desired( p_data, dp_data, ddp_data, g_d );

% The A matrix 
A = zeros( N, P );

% Interating along the sample points
for i = 1:P 
    t = t_data( i );
    A( :, i ) = fs.calc_multiple_ith( t, 1:N )/ fs.calc_whole_at_t( t );
end

% Linear Least-square
W = B * A' * ( A * A' )^-1;

% Rollout!
T  = Tp*4;
Nt = 5000;
t_result = linspace( 0, T, Nt+1 );

input_arr = fs.calc_forcing_term( t_result( 1:end-1 ), W, 0, eye( 2 ) );
[ y_result, ~, ~ ] = trans_sys.rollout( zeros( 2, 1 ), zeros( 2, 1), g_d, input_arr, 0, t_result  );

f = figure( ); a = axes( 'parent', f );
hold on; axis equal
plot( a, y_result( 1,: ), y_result( 2,: ) )
plot( a, p_data( 1,: ), p_data( 2,: ) )

