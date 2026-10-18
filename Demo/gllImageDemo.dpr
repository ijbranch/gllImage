(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   gllImage demo: the stand-alone TgllImageView and the data-aware TgllDBImage side by side, sharing one toolbar
///   (open, save, fit, zoom, rotate, flip, read-only). The controls are created in code, so the demo runs without the
///   design-time package installed.
/// </summary>
program gllImageDemo;

uses
  Vcl.Forms,
  gllImage.Consts in '..\Source\gllImage.Consts.pas',
  gllImage.Utils in '..\Source\gllImage.Utils.pas',
  gllImage.DragDrop in '..\Source\gllImage.DragDrop.pas',
  gllImage.View in '..\Source\gllImage.View.pas',
  gllImage.DB in '..\Source\gllImage.DB.pas',
  Demo.Main in 'Demo.Main.pas' {DemoMainForm};

{$R *.res}

begin

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'gllImage demo';
  Application.CreateForm( TDemoMainForm, DemoMainForm );
  Application.Run;

end.
