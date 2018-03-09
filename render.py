import axi
import sys
import textwrap
import json

from shapely.geometry import shape


def main():
    paths = []
    with open('./output/composed.geojson') as fp:
        for line in fp:
            js = json.loads(line)
            for p in  axi.shapely_to_paths(shape(js["geometry"])):
                paths.append(p)
    d = axi.Drawing(paths)
    d = d.scale_to_fit(11.69, 8.5, padding=0)
    d = d.sort_paths()
    d.dump_svg('./output/out.svg')
    # axi.draw(d)

if __name__ == '__main__':
    main()
