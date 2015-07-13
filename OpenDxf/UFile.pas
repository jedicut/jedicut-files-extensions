{   Copyright 2011 Jerome

    This file is part of OpenDxf.

    OpenDxf is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    OpenDxf is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with OpenDxf.  If not, see <http://www.gnu.org/licenses/>.

    The software Jedicut is allowed to statically and dynamically link this library.
}

unit UFile;

interface

uses
  SysUtils, Classes, UType, UTypePrivate, ActiveX;

  // Fonction renvoyant le code famille de la dll, ce code indique le type de la dll
  // Les codes possibles : voir UType.pas, fichier commun aux dll
  function GetDllFamily : byte; export

  // Méthode de la dll permettant de définir si la dll propose une IHM d'initialisation
  // GetDllToInit est obligatoirement renseigné si ShowDllForm est renseignée pour une dll de communication
  // function GetDllToInit : integer;

  // Méthode passant le Handle de l'application
  // procedure ShowDllForm(appHandle : HWND);

  procedure GetDescription(Cible : PChar; tailleCible: integer); export
  procedure GetFileExtension(Format : PChar; tailleCible: integer); export
  function OpenFileDll(Src : PChar ; var nbEx, nbIn : integer) : smallInt; export
  function LoadFileDll(var Profil : TCoordonneesProfil) : smallInt; export
  procedure GetProfileDescription(Cible : PChar; tailleCible: integer); export
  procedure GetProfileName(Cible : PChar; tailleCible: integer); export
  function SaveFileDll(Dest : PChar) : smallInt; export

  // Vu que dans dll USB
  //procedure LibererRessources; export;
  //function GetChauffeMachine : double; export;

  // Fonctions privées
  function OuvrirFichierDXF : smallInt;

implementation

uses
  Dialogs;

const TIME_OUT = 10000;

var
  profileName : ShortString;
  profileDescription : ShortString;
  CheminFichier : string;
  coordEx : array of TPointProfil;
  coordIn : array of TPointProfil;

  function Version : longint; stdcall ;external 'Dll\CNCTools.dll';
  function LireFichier( TableStruct : PPSafeArray ;
                        NomFichier : PPChar ;
                        var XMin : single;
                        var XMax : single;
                        var YMin : Single;
                        var YMax : Single;
                        pComment : PPChar) : longint; stdcall ; external 'Dll\CNCTools.dll';
  // Comment 256 au max


{-----------------------------------------------------------------}
{ Renvoie le type de la dll }
function GetDllFamily : byte;
begin
  Result := DLL_FAMILY_FILE_PROFIL_READ_ONLY;
end;

{-----------------------------------------------------------------}
{ Renvoie la description de la dll }
procedure GetDescription(Cible : PChar; tailleCible: integer);
var
  Description : ShortString;
  iVersion : longInt;
begin
  try
    iVersion := Version;
  except
  end;
  Description := ' (*.dxf) v0.1.' + IntToStr(iVersion);
  StrPLCopy(Cible, Description, tailleCible);
end;

{-----------------------------------------------------------------}
{ Renvoie l'extension correspondant au format de fichier supporté }
procedure GetFileExtension(Format : PChar; tailleCible: integer);
var
  Extension : ShortString;
begin
  Extension := '.dxf';
  StrPLCopy(Format, Extension, tailleCible);
end;

{-----------------------------------------------------------------}
{ Ouvre un fichier de profils }
{-----------------------------------------------------------------}
{ INPUT :
  - Src : PChar // Chemin et nom du fichier
  OUTPUT : array of TPoint
  - [0] (nbItems, 0), // Nombre de profils (pour les fichiers pouvant contenir plusieurs profils (dxf)
  - [1] (1, nbPoints1), // Profil 1, et nombre de points du profil 1
  - [2..1+nbPoint] (x, y), // Succession de points du premier profil
  - [1+nbPoint+1] (2, nbPoints2), // Profil 2, et nombre de points du profil 2
  - ...,
  Return :  <0 = erreur
            >0 = nombre de points lus
            =0 tout s'est bien passé, mais le nombre de point lu n'est pas retourné
}
function OpenFileDll(Src : PChar ; var nbEx, nbIn : integer) : smallInt;
var
  fsFichier : TFileStream;
  indicateur : integer;
  retour : smallInt;
begin
  retour := 0;
  CheminFichier := Src;

  try
    // Chargement du nom du profil par défaut
    profileName := ExtractFileName(CheminFichier);
    // Lecture du fichier
    retour := OuvrirFichierDXF;
    nbEx := Length(coordEx);
    nbIn := Length(coordIn);
  except
    retour:=-2;
  end;

  Result := retour;
end;

{-----------------------------------------------------------------}
{ Fonction renvoyant les points du profil préalablement chargé }
function LoadFileDll(var Profil : TCoordonneesProfil) : smallInt;
var
  i : integer;
begin
    // Copier les tableaux
    for i:=0 to Length(Profil.coordonneesExDecoupe)-1 do
    begin
      Profil.coordonneesExDecoupe[i].X := coordEx[i].X;
      Profil.coordonneesExDecoupe[i].Y := coordEx[i].Y;
      Profil.coordonneesExDecoupe[i].keyPoint := coordEx[i].keyPoint;
      Profil.coordonneesExDecoupe[i].valChauffe := coordEx[i].valChauffe;
    end;
    for i:=0 to Length(Profil.coordonneesInDecoupe)-1 do
    begin
      Profil.coordonneesInDecoupe[i].X := coordIn[i].X;
      Profil.coordonneesInDecoupe[i].Y := coordIn[i].Y;
      Profil.coordonneesInDecoupe[i].keyPoint := coordIn[i].keyPoint;
      Profil.coordonneesInDecoupe[i].valChauffe := coordIn[i].valChauffe;
    end;

    Result := 0;
end;

{-----------------------------------------------------------------}
{ Renvoie le nom du profil préalablement chargé,                  }
{ Par défaut, le nom est celui du fichier chargé                  }
procedure GetProfileName(Cible : PChar; tailleCible: integer);
begin
  StrPLCopy(Cible, profileName, tailleCible);
end;

{-----------------------------------------------------------------}
{ Renvoie la description du profil préalablement chargé,          }
{ si nécessaire                                                   }
procedure GetProfileDescription(Cible : PChar; tailleCible: integer);
begin
  StrPLCopy(Cible, profileDescription, tailleCible);
end;


{-----------------------------------------------------------------}
{ fonction d'ouverture d'un fichier *.DAT }
function OuvrirFichierDXF : smallInt;
var
  tabDonnees : array of TPointProfil;
  i, j, numeroLigne : integer;
  retour : smallInt;

  // Variables utilisées pour CNCTools
  pFichier : PChar;
  ppFichier : PPChar;
  Comment : array [0..255] of char;
  tableau : PSafeArray;
  pTableau : PPSafeArray;
  ArrayBounds : TSafeArrayBound;
  XMin, XMax, YMin, YMax : Single;
  pComment : PPChar;

  ArrayData : Pointer;
  //i : integer;
  sizeArrayData : integer;

begin
  try
    retour := 0;
    SetLength(tabDonnees, 0);
    Finalize(tabDonnees);

    // Utilisation de CNCTools
    ArrayBounds.lLbound:= 0;
    ArrayBounds.cElements:= 1;
    tableau := SafeArrayCreate( VT_VARIANT, 1, ArrayBounds );

    pTableau := @tableau;
    XMin := 0;
    XMax := 0;
    YMin := 0;
    YMax := 0;
    // ---

    try
      pFichier := PChar(CheminFichier);
      ppFichier := @pFichier;
      pComment := @Comment;
      retour := LireFichier(pTableau, ppFichier, XMin, XMax, YMin, YMax, pComment);
      sizeArrayData := retour;
    except
      retour := -9999;
    end;

    // Exploiter les points
    if (SafeArrayAccessData(pTableau^, ArrayData)=S_OK)and(retour>0) then
    begin
      // TODO Renvoyer la description du profil StrPLCopy(profileDescription, pComment, sizeOf(profileDescription);
      for i:=0 to sizeArrayData-1 do
      begin
        SetLength(tabDonnees, Length(tabDonnees)+1);
        tabDonnees[i].X := tableStruct(ArrayData)[i].X;
        tabDonnees[i].Y := tableStruct(ArrayData)[i].Y;
        tabDonnees[i].keyPoint := false;
        tabDonnees[i].valChauffe := 0; // Pour initialiser la valeur
      end;
      SafeArrayUnAccessData(pTableau^);
    end;

    numeroLigne := Trunc(Int(sizeArrayData/2)); // On divise par 2 pour répartir les points sur extrado et intrado
    // Remplir l'extrado. ATTENTION : il faut rentrer à l'envers (ordre décroissant)
    if ((numeroLigne>0)and(Length(tabDonnees)-1>=1)) then
    begin
      SetLength(coordEx, numeroLigne+1);
      for i := 0 to numeroLigne do
      begin
        coordEx[i].X := tabDonnees[numeroLigne-i].X;
        coordEx[i].Y := tabDonnees[numeroLigne-i].Y;
      end;
    end;

    // Remplir le tableau de l'intrado
    j := 0;
    if (Length(tabDonnees)-numeroLigne-1>0) then
    begin
      SetLength(coordIn, Length(tabDonnees)-numeroLigne);
      for i:=numeroLigne to Length(tabDonnees)-1 do
      begin
        coordIn[j].X := tabDonnees[i].X;
        coordIn[j].Y := tabDonnees[i].Y;
        j := j + 1;
      end;
    end;
    SetLength(tabDonnees, 0);
    Finalize(tabDonnees);
  except
    retour := -20;
  end;

  Result := retour;
end;


{-----------------------------------------------------------------}
{ Sauvegarde un fichier de profils }
{-----------------------------------------------------------------}
{ INPUT :
  - Dest : PChar // Chemin et nom du fichier
  - Profiles : array of TPoint
  - [0] (nbItems, 0),
  - [1] (1, nbPoints1),
  - [2..1+nbPoint] (x, y),
  - [1+nbPoint+1] (2, nbPoints2),
  - ...,
}
function SaveFileDll(Dest : PChar) : smallInt;
begin
  Result := -1;
end;

end.
