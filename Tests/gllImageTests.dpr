(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   DUnitX console runner for gllImage: the format-loader registry, TgllImageView and TgllDBImage.
/// </summary>
program gllImageTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

{$R *.res}

uses
  System.SysUtils,
  Vcl.Themes,
  Vcl.Styles,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  gllImage.Consts in '..\Source\gllImage.Consts.pas',
  gllImage.Utils in '..\Source\gllImage.Utils.pas',
  gllImage.DragDrop in '..\Source\gllImage.DragDrop.pas',
  gllImage.View in '..\Source\gllImage.View.pas',
  gllImage.DB in '..\Source\gllImage.DB.pas',
  TestGllImage in 'TestGllImage.pas',
  gllImage.Skia in '..\Source\gllImage.Skia.pas',
  TestGllImageSkia in 'TestGllImageSkia.pas';

var
  intfRunner: ITestRunner;
  intfResults: IRunResults;
  sXmlFile: string;

begin

  // A suite that puts a form or control on screen runs under the estate's VCL style (Ian, 2026-10-23), so the tests
  // meet the UI as it presents in use.  The .dproj embeds Aqua Light Slate; the lines below activate it.
  // TrySetStyle runs without its error dialog, which would hang an unattended run on a modal; a style that is
  // not linked stops the run with 251 (the runner-failed exit code) rather than letting it run unstyled.
  if not TStyleManager.TrySetStyle( 'Aqua Light Slate', False ) then
  begin
    System.Writeln( 'Aqua Light Slate VCL style is not linked into this runner - UI tests must run styled' );
    Halt( 251 );
  end;
  TStyleManager.UseParentPaintBuffers := True;

  try
    TDUnitX.CheckCommandLine;
    intfRunner         := TDUnitX.CreateRunner;
    intfRunner.UseRTTI := True;
    // A test that asserts nothing fails, and string comparisons are case-sensitive unless a test asks otherwise.
    intfRunner.FailsOnNoAsserts := True;
    Assert.IgnoreCaseDefault    := False;
    intfRunner.AddLogger( TDUnitXConsoleLogger.Create( True ) );

    // Results go to <exe name>-results.xml unless --xmloutput names another file.
    sXmlFile := TDUnitX.Options.XMLOutputFile;

    if ( sXmlFile = '' ) or SameText( ExtractFileName( sXmlFile ), 'dunitx-results.xml' ) then
      sXmlFile := ChangeFileExt( ParamStr( 0 ), '' ) + '-results.xml';

    intfRunner.AddLogger( TDUnitXXMLNUnitFileLogger.Create( sXmlFile ) );
    intfResults := intfRunner.Execute;

    if ( TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause ) then
    begin
      Write( 'Done, press Enter to continue.' );
      Readln;
    end;

    if ( not intfResults.AllPassed ) then ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      Writeln( E.ClassName, ': ', E.Message );
      ExitCode := EXIT_ERRORS;
    end;
  end;

end.
