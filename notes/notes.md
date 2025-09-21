# To crop run these dimensions

crop_pdf Fourier\ Transform.pdf 0 240 215 0 out.pdf

# To rotate run pdftk
pdftk out.pdf cat 1-endwest output rotated.pdf
