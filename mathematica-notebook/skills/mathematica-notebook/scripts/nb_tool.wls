(* nb_tool.wls — create and extract Mathematica notebooks via the Wolfram kernel.

   Usage (invoked via run_wolfram.sh, which dispatches to whichever kernel is available):
     nb_tool.wls create  <cells.json> <output.nb>
     nb_tool.wls extract <input.nb>   <cells.json>

   Cell JSON format: {"cells": [{"type": "Section", "content": "...", "raw": false}, ...]}
   - "type"    — cell style (Title, Section, Text, Input, ...)
   - "content" — cell content (plain string, OR a Wolfram expression string if raw=true)
   - "raw"     — optional bool; if true, content is parsed with ToExpression
*)

(* Argument handling: wolframscript -file populates $ScriptCommandLine,
   but `wolfram -script` leaves it empty and puts args in $CommandLine.
   Try $ScriptCommandLine first, then fall back to parsing $CommandLine. *)
args = If[Length[$ScriptCommandLine] >= 2,
  Rest[$ScriptCommandLine],
  Module[{cl = $CommandLine, pos},
    pos = FirstPosition[cl, "-script" | "-file", Missing["NotFound"]];
    If[! MissingQ[pos] && pos[[1]] + 1 <= Length[cl],
      Drop[cl, pos[[1]] + 1],
      {}
    ]
  ]
];

usage[] := (
  WriteString["stderr",
    "Usage:\n" <>
    "  nb_tool.wls create  <cells.json> <output.nb>\n" <>
    "  nb_tool.wls extract <input.nb>   <cells.json>\n"
  ];
  Exit[1]
);

If[Length[args] < 1, usage[]];

subcommand = args[[1]];

$validStyles = {
  "Title", "Chapter", "Section", "Subsection", "Subsubsection", "Subsubsubsection",
  "Text", "Input", "Output", "Code", "Item", "ItemNumbered", "Program", "Message",
  "Caption", "PageBreak"
};

(* ==== create ==== *)

(* Code-bearing styles: content should be wrapped in BoxData[...] so the
   frontend renders it as formatted code rather than a literal string. *)
$codeStyles = {"Input", "Code", "Program"};

cellFromSpec[spec_] := Module[{type, content, raw, parsed, body},
  type    = Lookup[spec, "type", "Text"];
  content = Lookup[spec, "content", ""];
  raw     = TrueQ @ Lookup[spec, "raw", False];

  If[!MemberQ[$validStyles, type],
    WriteString["stderr", "[warn] unknown cell type '" <> ToString[type] <> "', falling back to Text\n"];
    type = "Text";
  ];

  body = If[raw,
    parsed = Quiet @ ToExpression[content, InputForm, HoldComplete];
    If[Head[parsed] === HoldComplete && Length[parsed] == 1 && parsed =!= HoldComplete[Null],
      ReleaseHold[parsed]
      ,
      WriteString["stderr", "[warn] failed to parse raw content, using as string\n"];
      ToString[content]
    ]
    ,
    ToString[content]
  ];

  (* For code-bearing cells, wrap plain-string bodies in BoxData so the
     frontend renders them as formatted code. Raw bodies that are already
     box expressions (BoxData[...], RowBox[...], etc.) are passed through. *)
  If[MemberQ[$codeStyles, type] && StringQ[body],
    Cell[BoxData[body], type]
    ,
    Cell[body, type]
  ]
];

buildNotebook[specs_List] := Notebook[cellFromSpec /@ specs];

doCreate[jsonPath_, nbPath_] := Module[{data, specs, nb},
  If[!FileExistsQ[jsonPath],
    WriteString["stderr", "Error: input JSON not found: " <> jsonPath <> "\n"];
    Exit[1];
  ];
  data = Import[jsonPath, "RawJSON"];
  specs = Which[
    AssociationQ[data] && KeyExistsQ[data, "cells"], data["cells"],
    ListQ[data], data,
    True, (WriteString["stderr", "Error: JSON must be a list of cells or {\"cells\": [...]}\n"]; Exit[1])
  ];
  If[!ListQ[specs],
    WriteString["stderr", "Error: 'cells' must be a list\n"];
    Exit[1];
  ];
  nb = buildNotebook[specs];
  Put[nb, nbPath];
  WriteString["stdout", "Wrote " <> ToString[Length[specs]] <> " cells to " <> nbPath <> "\n"];
];

(* ==== extract ==== *)

(* Unwrap the common BoxData-wrapped-string case that `create` produces
   for code cells, so `extract` round-trips cleanly back to plain content. *)
cellToSpec[Cell[BoxData[s_String], style_String, ___]] :=
  <|"type" -> style, "content" -> s|>;
cellToSpec[Cell[content_, style_String, ___]] := If[
  StringQ[content],
  <|"type" -> style, "content" -> content|>,
  <|"type" -> style, "raw" -> True, "content" -> ToString[content, InputForm]|>
];
cellToSpec[other_] := <|"type" -> "Text", "raw" -> True, "content" -> ToString[other, InputForm]|>;

doExtract[nbPath_, jsonPath_] := Module[{nb, cells, specs},
  If[!FileExistsQ[nbPath],
    WriteString["stderr", "Error: input notebook not found: " <> nbPath <> "\n"];
    Exit[1];
  ];
  nb = Get[nbPath];
  If[Head[nb] =!= Notebook,
    WriteString["stderr", "Error: file is not a Wolfram Notebook expression\n"];
    Exit[1];
  ];
  (* Grab every leaf Cell[] in document order. Frontend-saved notebooks wrap
     cells in Cell[CellGroupData[{...}, Open]] to record grouping state —
     exclude those wrappers so we only capture actual content cells. *)
  cells = Cases[
    nb,
    c:Cell[first_, ___] /; Head[first] =!= CellGroupData :> c,
    Infinity
  ];
  specs = cellToSpec /@ cells;
  Export[jsonPath, <|"cells" -> specs|>, "RawJSON", "Compact" -> False];
  WriteString["stdout", "Extracted " <> ToString[Length[specs]] <> " cells from " <> nbPath <> "\n"];
];

(* ==== dispatch ==== *)

Which[
  subcommand === "create",
    If[Length[args] < 3, usage[]];
    doCreate[args[[2]], args[[3]]],
  subcommand === "extract",
    If[Length[args] < 3, usage[]];
    doExtract[args[[2]], args[[3]]],
  True,
    WriteString["stderr", "Unknown subcommand: " <> ToString[subcommand] <> "\n"];
    usage[];
];

Exit[0];
