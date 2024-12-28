#!/usr/bin/env python3
import argparse
import sys
from math import asin, cos, degrees, log, pi, radians, sin, sqrt, tan
from pathlib import Path
from typing import Any
import subprocess

DIR = Path(__file__).parent
output_file = DIR / "tiles.txt"
if output_file.exists():
    output_file.unlink()


def degree_to_tile(lat_deg, lon_deg, zoom) -> tuple[int, int]:
    """
    Converts lat/lon to tile coordinates at a given zoom level

    >>> degree_to_tile(44.883, -93.222, 6)
    (15, 23)
    """

    lat_rad = radians(lat_deg)
    n = 2.0**zoom
    x = int(n * ((lon_deg + 180.0) / 360.0))
    y = int(n * (1.0 - (log(tan(lat_rad) + (1 / cos(lat_rad))) / pi)) / 2.0)
    return x, y


def generate_tiles(
    max_zoom: int,
    bbox: tuple[float, float, float, float],
    start_zoom: int = 0,
) -> None:
    print(f"Generating tiles for zoom levels {start_zoom} to {max_zoom} for {bbox}")
    with open(output_file, "a") as f:
        for z in range(start_zoom, max_zoom + 1):
            min_x, max_y = degree_to_tile(lat_deg=bbox[1], lon_deg=bbox[0], zoom=z)
            max_x, min_y = degree_to_tile(lat_deg=bbox[3], lon_deg=bbox[2], zoom=z)
            print(f"Processing zoom level {z}")
            for x in range(min_x, max_x + 1):
                for y in range(min_y, max_y + 1):
                    if x < 0 or y < 0 or x >= 2**z or y >= 2**z:
                        continue
                    f.write(f"{z}/{x}/{y}\n")


def haversine(lat1, lon1, lat2, lon2):
    R = 6371  # Earth radius in kilometers
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = (
        sin(dlat / 2) ** 2
        + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    )
    c = 2 * asin(sqrt(a))
    return R * c


def bounding_box_from_point(lat, lon, radius_km) -> tuple[float, float, float, float]:
    R = 6371  # Earth radius in kilometers
    lat_rad = radians(lat)
    lon_rad = radians(lon)
    delta_lat = radius_km / R
    delta_lon = radius_km / (R * cos(lat_rad))

    min_lat = lat - degrees(delta_lat)
    max_lat = lat + degrees(delta_lat)
    min_lon = lon - degrees(delta_lon)
    max_lon = lon + degrees(delta_lon)

    return (min_lon, min_lat, max_lon, max_lat)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a list of map tiles.")
    parser.add_argument("max_zoom", type=int, help="Maximum zoom level")
    parser.add_argument(
        "--bbox",
        nargs=4,
        type=float,
        default=(-180, -85.06, 180, 85.06),
        help="Bounding box coordinates in left, bottom, right, top format: min_lon min_lat max_lon max_lat (default: global coordinates)",
    )
    parser.add_argument(
        "--latlon",
        nargs=3,
        type=float,
        metavar=("LAT", "LON", "RADIUS"),
        help="Latitude, Longitude, and Radius (in km) to generate bounding box",
    )
    parser.add_argument(
        "--global-zoom",
        type=int,
        help="Zoom level to use global coordinates (-180 to 180, -85.06 to 85.06)",
    )

    args = parser.parse_args()

    if args.latlon:
        if len(args.latlon) != 3:
            print("Error: latlon must have exactly 3 values: lat, lon, radius")
            sys.exit(1)
        bbox = bounding_box_from_point(
            lat=args.latlon[0], lon=args.latlon[1], radius_km=args.latlon[2]
        )
    else:
        if len(args.bbox) != 4:
            print("Error: bbox must have exactly 4 coordinates")
            sys.exit(1)
        bbox = args.bbox

    max_zoom = args.max_zoom

    if not (
        -180 <= bbox[0] <= 180
        and -180 <= bbox[2] <= 180
        and -85.06 <= bbox[1] <= 85.06
        and -85.06 <= bbox[3] <= 85.06
    ):
        print("Error: Invalid bbox coordinates")
        sys.exit(1)

    if args.global_zoom:
        generate_tiles(args.global_zoom, (-180, -85.06, 180, 85.06))
        generate_tiles(max_zoom, bbox, args.global_zoom + 1)
    else:
        generate_tiles(max_zoom, bbox)

    file_stats = output_file.stat()
    print(f"\nOutput file size: {file_stats.st_size:,} bytes")

    result = subprocess.run(['wc', '-l', str(output_file)], capture_output=True, text=True)
    print(f"Number of lines: {int(result.stdout.split()[0]):,}")
