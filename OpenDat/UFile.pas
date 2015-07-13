{   Copyright 2011 Jerome

    This file is part of OpenDat.

    OpenDat is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    OpenDat is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with OpenDat.  If not, see <http://www.gnu.org/licenses/>.

    The software Jedicut is allowed to statically and dynamically link this library.
}

unit UFile;

interface

uses
  SysUtils, Classes, UType;

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
  function OuvrirFichierDAT(fsFichier : TFileStream) : smallInt;

implementation

uses
  Dialogs;

const TIME_OUT = 10000;

var
  profileName : ShortString;
  profileDescription : ShortString;
  coordEx : array of TPointProfil;
  coordIn : array of TPointProfil;


{-----------------------------------------------------------------}
{ Renvoie le type de la dll }
function GetDllFamily : byte;
begin
  Result := DLL_FAMILY_FILE_PROFIL_READ_ONLY; //TODO Temporaire, le temps d'implémenter la lecture dans Jedicut
end;

{-----------------------------------------------------------------}
{ Renvoie la description de la dll }
procedure GetDescription(Cible : PChar; tailleCible: integer);
var
  Description : ShortString;
begin
  // Si on veut obtenir ça dans Jedicut : Profil (*.dat) v0.1
  // Il faut saisir ça dans la Description : ' (*.dat) v0.1'
  Description := ' (*.dat) v0.1';
  StrPLCopy(Cible, Description, tailleCible);
end;

{-----------------------------------------------------------------}
{ Renvoie l'extension correspondant au format de fichier supporté }
procedure GetFileExtension(Format : PChar; tailleCible: integer);
var
  Extension : ShortString;
begin
  Extension := '.dat';
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
}
function OpenFileDll(Src : PChar ; var nbEx, nbIn : integer) : smallInt;
var
  fsFichier : TFileStream;
  indicateur : integer;
  retour : smallInt;
begin
  try
    fsFichier := TFileStream.Create(Src, fmOpenRead or fmShareDenyNone);
    retour := 0;
  except
    retour := -1;
  end;

  try
    // Chargement du nom du profil par défaut
    profileName := ExtractFileName(Src);
    // Lecture du fichier
    retour := OuvrirFichierDAT(fsFichier);
    nbEx := Length(coordEx);
    nbIn := Length(coordIn);

    fsFichier.Free;

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
function OuvrirFichierDAT(fsFichier : TFileStream) : smallInt;
var
  tabDonnees : array of TPointProfil;
  donneeX, donneeY : string;
  clu : char;
  i, j : integer;
  numeroLigne : integer;
  valeur : string;
  valeurMemoire : string; // Pour la gestion du titre du profil
  bDonneeX : boolean; // Permet de savoir si le X a déjà été extrait
  pPremier : boolean;
  donnee : double;
  bMultiData : boolean; // Boolean permettant de ne pas prendre en compte les lignes contenant plus de 2 valeurs
  retour : smallInt;
  name : ShortString;
begin
  try
    retour := 0;
    //--- Initialisation ---//
    name:='';
    numeroLigne := 1;
    valeur:='';
    pPremier := true;
    bDonneeX := true;
    bMultiData := false;
    for i:=0 to fsFichier.Size do     //i:=0 car on incrémente de un en lecture
    begin
      fsFichier.Seek(i, soFromBeginning);
      fsFichier.Read(clu, 1);

      if clu in ['.'] then
      begin
        if ((valeur='.')or(valeur=',')) then valeur:='0.'
        else
          if ((valeur='-.')or(valeur='-,')) then valeur:='-0.'
          else
            valeur := valeur + clu;
      end;

      if clu in ['a'..'z', 'A'..'Z', '0'..'9', '-'] then
      begin
        valeur := valeur + clu;
      end;

      if ((clu=' ')or(clu=#9))or(clu=#10)or(i = fsFichier.Size)or(clu=',') then // #9 : tabulation
      begin
        valeurMemoire := valeur;
        valeur := StringReplace(valeur, '.', DecimalSeparator, [rfReplaceAll]);
        if TryStrToFloat(valeur, donnee) then
        begin
          // On stocke la donnée
          if bDonneeX then
          begin
            // La donnée est un x
            bDonneeX := false;
            donneeX := valeur;
            // Detection du bMultiData
            if donneeY <> '' then bMultiData := true;
          end else begin
            // La donnée est un y
            bDonneeX := true;
            donneeY := valeur;
          end;
          valeur := '';
        end else begin
          // La chaine n'est pas une valeur décimale, on récupère donc la valeur initiale
          valeur := valeurMemoire;
          if (numeroLigne=1)and(clu<>' ') then
          begin
            name := valeur;
            valeur := '';
          end;
          if (clu=#10) then
          begin
            donneeX := '';
            donneeY := '';
            valeur := '';
          end else begin
            valeur := valeur + clu;
          end;
        end;
      end;

      if ((clu = #10)or(i = fsFichier.Size)) then
      begin
        // Remplir tableau
        if not bMultiData then
        begin
          if (donneeX<>'')and(donneeY<>'') then
          begin
            if pPremier then
            begin
              SetLength(tabDonnees, 1);
              pPremier := false;
            end else begin
              SetLength(tabDonnees, Length(tabDonnees)+1);
            end;

            tabDonnees[Length(tabDonnees)-1].X := StrToFloat(donneeX);
            tabDonnees[Length(tabDonnees)-1].Y := StrToFloat(donneeY);
            donneeX := '';
            donneeY := '';
          end else begin
            // On est dans le cas d'un saut de ligne après une seule ligne de chiffres
            // On annule la seule ligne de données présente dans le tableau
            pPremier := true;
            valeur := '';
          end;
        end else begin
          bMultiData := false;
          bDonneeX := true;
          donneeX := '';
          donneeY := '';
        end;
        // On incrémente le numéro de ligne
        numeroLigne := numeroLigne + 1;
      end;
    end;
    //-------------------------//

    // si name='' on ne fait rien car ProfileName est initialisé avec le nom du fichier
    if name<>'' then
      profileName := name;
    // Recherche du nombre de point pour l'extrado
    numeroLigne := 1;
    if (Length(tabDonnees)>2) then
    begin
      donnee := tabDonnees[0].X;
      for i := 1 to Length(tabDonnees)-1 do
      begin
        if ((tabDonnees[i].X>donnee)or(tabDonnees[i].X=0)) then
          break
        else
        begin
          if i>1 then numeroLigne := numeroLigne + 1;
          donnee := tabDonnees[i].X;
        end;
      end;
    end else begin
      retour := -10;
    end;

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
var
  fichier : TextFile;
  strTemp, buffX, buffY : string;
  i, longueur : integer;
  retour : smallInt;

  // TODO : Paramètre
  nomProfil : PChar;
begin
  AssignFile(fichier, Dest);
  Rewrite(fichier);
  // Ecriture du nom du profil
  if (nomProfil<>'') then
  begin
    Writeln(fichier, nomProfil);
    Writeln(fichier, '');
  end;
  // Extrado
  longueur := Length(coordEx);
  for i:=0 to longueur-1 do
  begin
    buffX:=StringReplace(FloatToStr(coordEx[longueur-1-i].X), DecimalSeparator, '.', [rfReplaceAll]);
    buffY:=StringReplace(FloatToStr(coordEx[longueur-1-i].Y), DecimalSeparator, '.', [rfReplaceAll]);
    strTemp := buffX + ' ' + buffY;
    Writeln(fichier, strTemp);
  end;
  // Intrado
  longueur := Length(coordIn);
  for i:=0 to longueur-1 do
  begin
    buffX:=StringReplace(FloatToStr(coordIn[i].X), DecimalSeparator, '.', [rfReplaceAll]);
    buffY:=StringReplace(FloatToStr(coordIn[i].Y), DecimalSeparator, '.', [rfReplaceAll]);
    strTemp := buffX + ' ' + buffY;
    Writeln(fichier, strTemp);
  end;
  // Fermeture du fichier
  CloseFile(fichier);

  Result := retour;
end;

end.
