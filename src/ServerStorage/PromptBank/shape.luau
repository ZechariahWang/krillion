--!strict
return {
	id = "shape",
	prompt = "Name a shape",
	answers = {
		Plankton = {
			"circle", "square", "triangle", "rectangle",
		},
		TooClever = {
			"blob", "squiggle",
		},
		Schooler = {
			"oval", "star", "heart", "hexagon", "pentagon", "diamond", "cube", "sphere", "cylinder", "cone", "pyramid",
			"octagon", "crescent", "trapezoid", "rhombus",
		},
		Rare = {
			"parallelogram", "ellipse", "prism", "semicircle", "kite", "cross", "arrow", "spiral", "hemisphere", "cuboid",
			"triangular prism", "tetrahedron", "polygon", "quadrilateral", "heptagon", "decagon", "nonagon", "torus",
			"square pyramid", "oblong", "pentagram", "hexagram",
		},
		DeepCut = {
			"octahedron", "dodecahedron", "ellipsoid", "chevron", "lune", "squircle", "obround", "tesseract", "ring", "dome",
			"dodecagon", "icosahedron", "annulus", "hendecagon", "octagram", "rounded rectangle", "right triangle",
			"isosceles triangle", "scalene triangle", "equilateral triangle",
		},
		OneInAKrillion = {
			"trapezium", "lemniscate", "cardioid", "deltoid", "astroid", "reuleaux triangle", "vesica piscis",
			"mobius strip", "paraboloid", "hyperboloid", "klein bottle",
		},
	},
	aliases = {
		["donut"] = "torus", ["doughnut"] = "torus", ["ball"] = "sphere", ["crescent moon"] = "crescent",
		["rectangular prism"] = "cuboid", ["septagon"] = "heptagon", ["enneagon"] = "nonagon",
		["undecagon"] = "hendecagon", ["mobius band"] = "mobius strip",
	},
}
