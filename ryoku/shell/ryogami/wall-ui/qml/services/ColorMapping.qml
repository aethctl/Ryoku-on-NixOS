pragma Singleton
import QtQuick

QtObject {
    id: cm
    
    readonly property var colorAliases: ({
        "red": 0, "crimson": 0, "scarlet": 0, "maroon": 0, "burgundy": 0, "wine": 0,
        "orange": 1, "amber": 1, "gold": 2, "golden": 2, "coral": 1, "peach": 1,
        "brown": 1, "rust": 1, "copper": 1, "sepia": 1, "tan": 1,
        "yellow": 2, "beige": 2, "cream": 2,
        "lime": 3, "chartreuse": 3, "yellow-green": 3,
        "green": 4, "emerald": 4, "olive": 4, "mint": 4, "forest": 4, "dark green": 4, "neon": 4,
        "teal": 5, "sea green": 5, "aqua": 5,
        "cyan": 6, "turquoise": 6,
        "sky blue": 7, "sky": 7, "light blue": 7,
        "blue": 8, "cobalt": 8,
        "navy": 9, "dark blue": 9, "indigo": 9, "dark purple": 9,
        "violet": 10, "purple": 10, "magenta": 10, "lavender": 10, "lilac": 10, "plum": 10,
        "pink": 11, "rose": 11, "fuchsia": 11, "hot pink": 11, "salmon": 11,
        "neutral": 99, "gray": 99, "grey": 99, "black": 99, "white": 99,
        "grayscale": 99, "monochrome": 99
    })

    readonly property var synonyms: ({
        "peaceful": ["serene", "tranquil", "calm"],
        "dreamy": ["ethereal", "surreal"],
        "mysterious": ["eerie", "ominous", "mystical"],
        "dark": ["moody", "gloomy", "somber", "shadowy"],
        "cozy": ["warm"],
        "monochrome": ["grayscale", "grey", "gray"],
        "sci-fi": ["scifi", "futuristic"],
        "cyberpunk": ["neon", "vaporwave"],
        "mountain": ["mountains", "hills"],
        "flower": ["flowers", "floral", "bloom", "blossom", "botanical"],
        "tree": ["trees", "foliage", "leaves"],
        "building": ["buildings", "architecture"],
        "plant": ["plants"],
        "ocean": ["seascape", "coastal", "waves", "beach"],
        "city": ["urban", "cityscape", "skyline"],
        "night": ["nighttime"],
        "outdoor": ["outdoors", "exterior"],
        "indoor": ["indoors", "interior"],
        "shadow": ["shadows", "silhouette"],
        "star": ["stars", "celestial", "cosmic", "nebula"],
        "cloud": ["clouds", "cloudy"],
        "rock": ["rocks", "rugged"],
        "sunset": ["dusk", "twilight"]
    })

    property var _mergeMap: {
        var m = {}
        for (var target in synonyms) {
            var sources = synonyms[target]
            for (var i = 0; i < sources.length; i++)
                m[sources[i]] = target
        }
        return m
    }

    function colorToHue(colorName) {
        var name = colorName.toLowerCase()
        if (colorAliases.hasOwnProperty(name)) return colorAliases[name]
        for (var alias in colorAliases) {
            if (alias.indexOf(name) !== -1 || name.indexOf(alias) !== -1)
                return colorAliases[alias]
        }
        return 99
    }

    function mergeSynonyms(tags) {
        var result = []
        var seen = {}
        for (var i = 0; i < tags.length; i++) {
            var canonical = _mergeMap[tags[i]] || tags[i]
            if (!seen[canonical]) {
                result.push(canonical)
                seen[canonical] = true
            }
        }
        return result
    }
}
