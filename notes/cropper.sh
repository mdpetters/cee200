#!/bin/bash

function crop_pdf() {
    input=$1
    output=$6

    pdf_info=$(pdfinfo -box $input)
    currentWidth=$(echo "$pdf_info" | grep "Page size:" | awk '{print $3}')
    currentHeight=$(echo "$pdf_info" | grep "Page size:" | awk '{print $5}')

    left=$2
    bottom=$3
    right=$(echo "$currentWidth - $4" | bc)
    top=$(echo "$currentHeight - $5" | bc)

    gs -o $output -sDEVICE=pdfwrite -c "[/CropBox [$left $bottom $right $top] /PAGES pdfmark" -f $input
}
