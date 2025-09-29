def get_wikidata_uri(value)-> str:

    # this function is used in OntoRefine to map taxonomy term IDs to Wikidata URIs
    import json
    import urllib2

    url = "https://raw.githubusercontent.com/culturecreates/artsdata-planet-atc/refs/heads/main/genre_mapping.json"
    mapping_list = json.load(urllib2.urlopen(url))

    mapping = {str(item['tid']): item['wikidata_uri'] for item in mapping_list}

    tid = str(value).strip() if value else None
    if tid in mapping:
        return mapping[tid]
    else:
        return None
