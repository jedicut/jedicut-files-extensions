// Types spécifiques à la gestion des DXF avec la dll CNCTools.dll
unit UTypePrivate;

interface

uses ActiveX;

type
  PointPLT = packed record
    X : single; // Abcisse
    Y : single; // Ordonné
    Cde : array[0..3] of char; // Commande (PU ou PD)
    numSequence : array[0..3] of char; // N° de séquence de la découpe
  end;

  PPSafeArray = ^PSafeArray;
  PPChar = ^PChar;

  tableStruct = array of PointPLT;

implementation

end.
