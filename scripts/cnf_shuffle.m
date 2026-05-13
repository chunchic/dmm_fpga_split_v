function cnf_shuffle(inFile, outFile, seed, restarts)

    if nargin < 3 || isempty(seed)
        rng('shuffle');
    else
        rng(seed);
    end
    if nargin < 4 || isempty(restarts)
        restarts = 20;
    end

    fid = fopen(inFile,'r');
    if fid < 0
        error("Cannot open input file: %s", inFile); 
    end
    raw = textscan(fid,'%s','Delimiter','\n','Whitespace','');
    fclose(fid);
    raw = raw{1};

    header = {};
    clauses = {};
    nVars = [];

    for i = 1:numel(raw)
        line = strtrim(raw{i});
        if isempty(line) 
            continue;
        end
        if startsWith(line,'c')
            header{end+1,1} = raw{i}; 
        elseif startsWith(line,'p')
            header{end+1,1} = raw{i};
            toks = regexp(line,'^p\s+cnf\s+(\d+)\s+(\d+)','tokens','once');
            if ~isempty(toks)
                nVars = str2double(toks{1});
            end
        else
            clauses{end+1,1} = raw{i};
        end
    end

    if isempty(clauses)
        error("No clause lines found."); 
    end
    nClauses = numel(clauses);

    %%
    varSets = cell(nClauses,1);
    maxVarSeen = 0;
    for i = 1:nClauses
        nums = sscanf(clauses{i}, '%d');
        if isempty(nums)
            error("Bad clause line %d", i); 
        end
        if nums(end) == 0
            nums = nums(1:end-1); 
        end
        vs = unique(abs(nums(:)))';
        varSets{i} = vs;
        if ~isempty(vs)
            maxVarSeen = max(maxVarSeen, max(vs)); 
        end
    end
    if isempty(nVars)
        nVars = maxVarSeen; % fallback if no p-line found/parsed
    else
        nVars = max(nVars, maxVarSeen);
    end

    %% 
    bestOrder = [];
    bestViol  = inf;

    for r = 1:restarts
        [ord, viol] = one_greedy_build(varSets, nVars);
        if viol < bestViol
            bestViol = viol;
            bestOrder = ord;
            if bestViol == 0
                break; % perfect schedule found
            end
        end
    end

    fprintf("Shuffled %d clauses. 3-in-a-row violations: %d\n", nClauses, bestViol);

    
    fid = fopen(outFile,'w');
    if fid < 0
        error("Cannot open output file: %s", outFile); 
    end
    for i = 1:numel(header)
        fprintf(fid,"%s\n", header{i});
    end
    for k = 1:nClauses
        fprintf(fid,"%s\n", strtrim(clauses{bestOrder(k)}));
    end
    fclose(fid);

    fprintf("Wrote: %s\n", outFile);
end

%%
function [order, violations] = one_greedy_build(varSets, nVars)
% no variable appears in 3 clauses in a row

    n = numel(varSets);
    remaining = true(1,n);
    order = zeros(1,n);

    % Track which vars appeared in previous 1 and previous 2 clauses
    prev1 = false(1,nVars);  % vars in last clause
    prev2 = false(1,nVars);  % vars in clause before last
    violations = 0;

    % Start from random clause
    start = randi(n);
    order(1) = start;
    remaining(start) = false;
    v = varSets{start};
    prev1(v) = true;

    for pos = 2:n
        candIdx = find(remaining);
        best = [];
        bestBad = inf;
        bestOverlap = inf;

        for t = 1:numel(candIdx)
            idx = candIdx(t);
            vs = varSets{idx};

            % "Bad" vars are those already in prev1 AND prev2: would become 3-in-row
            badCount = nnz(prev1(vs) & prev2(vs));

            % Secondary score: prefer fewer vars repeated from prev1 (helps hazards)
            overlap1 = nnz(prev1(vs));

            if badCount < bestBad || (badCount == bestBad && overlap1 < bestOverlap)
                bestBad = badCount;
                bestOverlap = overlap1;
                best = idx;
                if bestBad == 0 && bestOverlap == 0
                    % can't beat perfect on both metrics
                end
            end
        end

        order(pos) = best;
        remaining(best) = false;

        % update violation count
        vs = varSets{best};
        violations = violations + nnz(prev1(vs) & prev2(vs));

        % shift history: prev2 <- prev1, prev1 <- current
        prev2 = prev1;
        prev1 = false(1,nVars);
        prev1(vs) = true;
    end
end
