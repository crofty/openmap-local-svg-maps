require 'json'

def run_command(command)
  puts command
  system(command) or raise "Command failed"
end

ll     = "51.466727, -0.035276"
layers = ["Road", "RailwayTrack", "RailwayTunnel", "Building"]

lat, lng = ll.split(', ')

zoom     = 13 # Controls the area plotted
scale    = 1  # Finer grained control over area plotted

width    = 1169
height   = 850

output_dir = "output"

run_command <<-SH
  rm -rf #{output_dir}
  mkdir #{output_dir}
SH

js = <<-JS
var geoViewport = require('@mapbox/geo-viewport');

const bounds = geoViewport.
  bounds([#{lng}, #{lat}], #{zoom}, [#{width*scale},#{height*scale}])

console.log(JSON.stringify(bounds));
JS

json_bbox             = %x[node -e "#{js}"].chomp
left,bottom,right,top = JSON.parse(json_bbox)

composed_filename = File.join(output_dir, 'composed.geojson')

layers.each do |layer|
  vrt_filename   = File.join(output_dir, "OpenMap-#{layer}.vrt")
  projected_json = File.join(output_dir, "#{layer}-projected.geojson")
  json_filename  = File.join(output_dir, "#{layer}.geojson")
  svg_filename   = File.join(output_dir, "#{layer}.svg")

  run_command <<-SH
    ruby build_vrt.rb #{layer} #{vrt_filename}
  SH

  run_command  <<-SH
  docker run  -v $(pwd):/gdal -v /mnt/NAS/Maptrail:/mnt/NAS/Maptrail -w /gdal geographica/gdal2 \
      ogr2ogr \
        -f "GeoJSON" \
        -t_srs EPSG:4326 \
        -s_srs "+proj=tmerc +lat_0=49 +lon_0=-2 +k=0.999601 +x_0=400000 +y_0=-100000 +ellps=airy +units=m +no_defs +nadgrids=./OSTN02_NTv2.gsb" \
        -spat #{left} #{top} #{right} #{bottom} \
        -spat_srs EPSG:4326 \
        -clipdst #{left} #{top} #{right} #{bottom} \
        #{json_filename} #{vrt_filename}
  SH

  run_command  <<-SH
    npx geoproject 'd3.geoMercator().fitSize([#{width}, #{height}], d)' < #{json_filename} |
      node_modules/.bin/ndjson-split 'd.features' > #{projected_json}
  SH

  run_command  <<-SH
    cat #{projected_json} >> #{composed_filename}
  SH

  run_command  <<-SH
    npx geo2svg -n -w #{width} -h #{height} < #{projected_json} > #{svg_filename}
  SH
end

run_command  <<-SH
  npx geo2svg -n -w #{width} -h #{height} < #{composed_filename} > output/composed.svg
SH
