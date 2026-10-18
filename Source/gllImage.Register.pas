(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

(*
  gllImage.Register - Component palette registration
  Version: 4.0

  Description:
    Registers TgllDBImage and TgllImageView on the gllImage palette page. Design-time only: compiled into
    gllImageD, never into an application.
*)

unit gllImage.Register;

interface

/// <summary>Registers the gllImage components on the component palette.</summary>
procedure Register;

implementation

{$R gllImage.Register.dcr}

uses
  System.Classes,
  gllImage.View,
  gllImage.DB;

procedure Register;
begin

  RegisterComponents( 'gllImage', [ TgllDBImage, TgllImageView ] );

end;

end.
