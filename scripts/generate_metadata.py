#!/bin/env python3
import argparse
from curses import raw
import os
from pathlib import Path
from typing import Any
import mapbox_vector_tile
import json
from google.protobuf import message
import gzip
import requests


def extract_fields(
    pbf_directory: Path, expected_layer_ids: list[str]
) -> dict[str, dict[str, str]]:s
    fields = {}

    for file_path in pbf_directory.rglob("*"):
        if file_path.is_dir() or file_path.stat().st_size < 5000:  # Skip files smaller than 5K
            continue
        print(f"Processing {file_path}")
        with open(file_path, "rb") as f:
            raw_data = f.read()
            if raw_data.startswith(b"\x1f\x8b"):  # Check if gzipped
                raw_data = gzip.decompress(raw_data)
            tile = mapbox_vector_tile.decode(tile=raw_data)
            for layer_name, layer in tile.items():
                if layer_name not in fields:
                    fields[layer_name] = {}
                for feature in layer["features"]:
                    for key in feature["properties"].keys():
                        if isinstance(feature["properties"][key], bool):
                            fields[layer_name][key] = "Boolean"
                        elif isinstance(feature["properties"][key], (int, float)):
                            fields[layer_name][key] = "Number"
                        else:
                            fields[layer_name][key] = "String"

            # We can be done once we've seen all of the layers we expect
            if all(layer_id in fields for layer_id in expected_layer_ids):
                break
    return fields


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate metadata from PBF files for use in mbtiles \
                                     https://github.com/mapbox/mbtiles-spec/blob/master/1.3/spec.md#vector-tileset-metadata"
    )
    parser.add_argument(
        "--name",
        required=True,
        help="Name of the tileset",
    )
    parser.add_argument(
        "pbf_directory",
        type=Path,
        help="Directory containing PBF files",
    )
    parser.add_argument(
        "output_file",
        type=Path,
        help="where to put the metadata.json file",
    )
    args = parser.parse_args()

    tegola_response = requests.get(
        "http://localhost:9090/capabilities/mvt_power.json"
    )
    tegola_metadata = tegola_response.json()

    if not tegola_metadata["tilejson"].startswith("2"):
        raise ValueError("This script only supports Tegola TileJSON v2, if they moved to v3 that would actually help a lot.")

    metadata = {
        "name": args.name,
        "attribution": tegola_metadata["attribution"],
        "description": tegola_metadata["description"],
        "format": "pbf",
        "compression": "gzip",
        "bounds": ",".join([str(x) for x in tegola_metadata["bounds"]]),
        "center": ",".join([str(x) for x in tegola_metadata["center"]]),
        "minzoom": tegola_metadata["minzoom"],
        "maxzoom": tegola_metadata["maxzoom"],
        "type": "overlay",
        "version": "4.0.3",
        "json": {"vector_layers": tegola_metadata["vector_layers"]},
    }

    # Convert vector_layers from tilesJSON v2 to v3
    # PMTiles requires tileJSON v3 vector_layers https://github.com/mapbox/tilejson-spec/blob/22f5f91e643e8980ef2656674bef84c2869fbe76/3.0.0/README.md#332-fields
    # Which links to: https://github.com/mapbox/tilejson-spec/blob/22f5f91e643e8980ef2656674bef84c2869fbe76/3.0.0/README.md#33-vector_layers
    layer_ids = list(map(lambda l: l["id"], metadata["json"]["vector_layers"]))
    fields = extract_fields(
        pbf_directory=args.pbf_directory, expected_layer_ids=layer_ids
    )

    for idx, layer in enumerate(metadata["json"]["vector_layers"]):
        layer_metadata = {
            "id": layer["id"],
            "description": "",
            "minzoom": layer["minzoom"],
            "maxzoom": layer["maxzoom"],
            "fields": fields[layer["id"]],
        }
        metadata["json"]["vector_layers"][idx] = layer_metadata

    metadata["json"] = json.dumps(metadata["json"])
    with open(args.output_file, "w") as f:
        json.dump(metadata, f, indent=2)
