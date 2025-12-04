import Foundation

// Example usage of the integrated XorShift32 and matrix generation
// This script demonstrates how to generate matrices compatible with MATLAB analysis

let n = 40

// Choose a seed. You can also hardcode one like 123456789
var seed = XorShift32.generateSeed()

// Generate matrix using the integrated function
let matrix = generateBlackWhiteMatrix(seed: seed, size: n)

// Print or persist
print("seed=\(seed)")
for row in matrix {
    print(row.map(String.init).joined(separator: ","))
}

// Optional: write CSV
let csv = matrix.map { $0.map(String.init).joined(separator: ",") }.joined(separator: "\n")
try csv.write(to: URL(fileURLWithPath: "bw_\(seed).csv"), atomically: true, encoding: .utf8)
