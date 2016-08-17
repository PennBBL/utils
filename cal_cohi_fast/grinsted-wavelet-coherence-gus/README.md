
# Added files to the Cross wavelet and wavelet coherence toolbox for MATLAB

####wtcMatrix.m                  : 
faster version of computing coherence matrix only
####cohi_mat_fast.sh             : 
bash call to the wtcMatrix.m function
####run_timeSeries2mat.m         : 
use the original wtc.m to compute the pairwise coherence matrix
####run_timeSeries2matFastCohi.m : 
use the wtcMatrix.m to compute the coherence matrix in a faster mode




\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#
\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#\#

The followings are the README.md from the original wavelet coherence toolbox

# Cross wavelet and wavelet coherence toolbox for MATLAB

*Aslak Grinsted, John Moore and Svetlana Jevrejeva*

[Website of the toolbox](http://www.glaciology.net/wavelet-coherence)

Grinsted, A., J. C. Moore, S. Jevrejeva (2004), Application of the cross wavelet transform and wavelet coherence to geophysical time series, Nonlin. Process. Geophys., 11, 561566 [link](http://www.glaciology.net/Home/PDFs/Announcements/Application-of-the-cross-wavelet-transform-and-wavelet-coherence-to-geophysical-time-series-)




### Licensing
Most of the routines included are licensed with the license. But please read details in individual files, as it includes some codes that are not authored by us.

### Acknowledgements
We would like to thank the following people for letting us include their programs in our package. See the licensing details in the individual files.

* Torrence and Compo for CWT software.
* Eric Breitenberger for AR1NV
