% shuffle_cnf_max2_consecutive
% Reorders DIMACS CNF clauses so that no variable index appears in 3
% consecutive clauses (sign ignored). I.e., for any variable v, it is
% forbidden that v appears in clauses i, i+1, and i+2.
%
% Usage:
%   shuffle_cnf_max2_consecutive("in.cnf","out.cnf");
%   shuffle_cnf_max2_consecutive("in.cnf","out.cnf", 1, 30);
%
% Params:
%   seed      (optional) RNG seed. Default: shuffle
%   restarts  (optional) number of random restarts. Default: 20
