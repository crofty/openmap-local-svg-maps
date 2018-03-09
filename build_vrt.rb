require 'nokogiri'

layer_name = ARGV[0]
vrt_name   = ARGV[1]
base_dir   = '/mnt/NAS/Maptrail/Mapping Data/OS Open Map Local'
shapefiles = Dir.glob("#{base_dir}/*/*_#{layer_name}.shp")

command = <<-SH
  python ogr2vrt.py -relative '#{shapefiles.first}' #{vrt_name}
SH
system(command)

doc = File.open(vrt_name) { |f| Nokogiri::XML(f) }

layer_template = doc.xpath('//OGRVRTLayer').first
layer_template.remove

doc.xpath("//OGRVRTDataSource").first.inner_html = '<OGRVRTUnionLayer name="Buildings"/>'

layers = shapefiles.map do |path_to_shapefile|
  layer = layer_template
  name = File.basename(path_to_shapefile,'.shp')
  layer['name'] = name
  layer.css('SrcDataSource')[0].inner_html = path_to_shapefile
  layer.css('SrcLayer')[0].inner_html = name
  layer.to_xml
end.join

doc.css("OGRVRTUnionLayer").first.inner_html = layers
File.write(vrt_name, doc.to_xml)
