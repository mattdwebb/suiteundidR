# Inference

Native analytic clustered inference and native-studentized RI are N/A.
Official UN-DID displays other standard errors; those are not presumed to be
a canonical cluster VCE for this suite target.

Jackknife deletes every input inference cluster. Removing the only treated
cluster in one cohort is allowed when another supported aggregate remains
estimable. Recompute the surviving school-time effects and normalized weights;
do not carry over full-sample denominators. A deletion with no estimable aggregate
(such as loss of the only eligible control) fails. Return every deletion slot and
a missing p-value on any failed deletion.
CV3J = (G-1)/G * sum((theta[-g]-mean(theta[-g]))^2).
Student t uses G-1 degrees of freedom. Zero or roundoff-scale standard errors
are numerical failures, never p=1.

Inclusive tails use 64 machine eps * max(1, statistic magnitudes) for numerical
ties. The p-value is (1+hits)/(B+1). Failed draws are not dropped or counted
as successful draws; the affected method returns an unavailable p-value.
R and Stata support exact multiset enumeration through 100000 total assignments and
seeded unique random sampling otherwise; sampling preserves the caller's RNG
state and has a documented bounded retry budget. Supplied matrices are
recommended for cross-language reproducibility. Generator seeds need not
produce identical draws across languages; supplied matrices do.
