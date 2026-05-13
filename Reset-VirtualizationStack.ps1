<#
.SYNOPSIS
    Outil graphique de désactivation complète de la pile de virtualisation Windows
    (VBS, Device Guard, Credential Guard, HVCI, Hyper-V, Windows Hypervisor Platform).

.DESCRIPTION
    Préparation d'un poste pour les TP VMware Workstation : libère VT-x/EPT afin
    que les hyperviseurs de type 1 imbriqués (ESXi notamment) puissent démarrer.

    L'outil procède en 4 étapes :
      1. Diagnostic complet de l'état actuel
      2. Sélection des actions de remédiation
      3. Exécution avec log temps réel
      4. Vérification finale et redémarrage

.NOTES
    Auteur  : Easyformer — Plateforme TSSR
    Version : 1.1
    Cible   : Windows 10 / 11 (Pro & Entreprise) — toutes éditions modernes
#>

# ============================================================================
#  AUTO-ÉLÉVATION ADMINISTRATEUR
#  (ce bloc DOIT rester avant tout import : pas de #Requires sinon PowerShell
#   refuse de charger le fichier avant même d'arriver ici)
# ============================================================================
$currentId = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPr = New-Object Security.Principal.WindowsPrincipal($currentId)
if (-not $currentPr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ''
    Write-Host '  Privilèges administrateur requis.' -ForegroundColor Yellow
    Write-Host '  Relancement automatique en mode élevé...' -ForegroundColor Gray
    Write-Host ''
    try {
        # Débloquer le fichier si marqué « venant d'Internet »
        try { Unblock-File -Path $PSCommandPath -ErrorAction SilentlyContinue } catch { }

        $argList = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', "`"$PSCommandPath`""
        )
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host '  Échec de l''élévation : annulé par l''utilisateur ou UAC bloqué.' -ForegroundColor Red
        Write-Host '  Lancez PowerShell en tant qu''administrateur et relancez le script.' -ForegroundColor Red
        Start-Sleep -Seconds 4
    }
    exit
}


# ============================================================================
#  RESSOURCES VISUELLES (logo et icône Easyformer encodés en base64)
# ============================================================================
$LogoBase64 = @'
/9j/4AAQSkZJRgABAQAAAQABAAD/4gHYSUNDX1BST0ZJTEUAAQEAAAHIAAAAAAQwAABtbnRyUkdCIFhZWiAH4AABAAEAAAAAAABhY3NwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAA9tYAAQAAAADTLQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAlkZXNjAAAA8AAAACRyWFlaAAABFAAAABRnWFlaAAABKAAAABRiWFlaAAABPAAAABR3dHB0AAABUAAAABRyVFJDAAABZAAAAChnVFJDAAABZAAAAChiVFJDAAABZAAAAChjcHJ0AAABjAAAADxtbHVjAAAAAAAAAAEAAAAMZW5VUwAAAAgAAAAcAHMAUgBHAEJYWVogAAAAAAAAb6IAADj1AAADkFhZWiAAAAAAAABimQAAt4UAABjaWFlaIAAAAAAAACSgAAAPhAAAts9YWVogAAAAAAAA9tYAAQAAAADTLXBhcmEAAAAAAAQAAAACZmYAAPKnAAANWQAAE9AAAApbAAAAAAAAAABtbHVjAAAAAAAAAAEAAAAMZW5VUwAAACAAAAAcAEcAbwBvAGcAbABlACAASQBuAGMALgAgADIAMAAxADb/2wBDAAUDBAQEAwUEBAQFBQUGBwwIBwcHBw8LCwkMEQ8SEhEPERETFhwXExQaFRERGCEYGh0dHx8fExciJCIeJBweHx7/2wBDAQUFBQcGBw4ICA4eFBEUHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh7/wAARCABaAGwDASIAAhEBAxEB/8QAHAABAAIDAQEBAAAAAAAAAAAAAAYHBAUIAwIB/8QAQRAAAQMDAwIDBQQGBwkAAAAAAQIDBAUGEQASIQcxEyJBCBQyUWEVUnGBIzNCkbHCFhgkYnKFwTRDRFWChJSh0//EABoBAAIDAQEAAAAAAAAAAAAAAAADAQIEBQb/xAArEQABBAIBAwIGAgMAAAAAAAABAAIDESExEgRBYSJRBRMycYGxJJGh8PH/2gAMAwEAAhEDEQA/AOy9NNNCE001rLrXUmraqL1GcbRUW4y1xi4jenekZAI9QcY/PQgLZKISkqUQAOST6aht49VenFoNum4r0osJxpIUqP7yHH8H1DSMrP5JOq/idTen/UyxpNMvyMims7B78wuWpvYe25KklKiM9sZPzA1yb1X6Fw4M16b0zrj9wUz4kxJkVyPKSPkhakpbfHr5cK/unGTRsjXaKu6NzdhdN1v2x+kdPqCo0Rm46s0n/iYkFCW1fgHXEL/ekaw/66fSr/kl4f8Ahx//AL64mptiV+RHM2pNNUGnJUUqmVVRjt5HcJBG9wjnyoSo8HjUotFFoU6ots0K0ahfcxKwFzZyfBipIPmDMUZLnHIU6vkEZaQRq5NKgF6XcPTX2hqF1FqSIdpWJfc5G8JdlGDHRGYHzW6p8JHAJxncccAnjVzaqPpf1ItSl9O7bpFUnNwa2zSo6ZcR2KYhVIDSS8QFJSn49xJHHfGdeVg9Sqj1D6omn0dPuluUqMuRIcAJVLWSENgn9lOSpQHdWw5440v5jboJgjdVlXDppppiWmmmmhCaaaaEJr5dWhptTjiglCAVKJ9ANfWqy9pG8f6KdO3o8V3ZU6uow4u0+ZCSMuOfglORn7ykfPUE0LUtHI0FH+g/Tq3VtSL6kQGnZFSlPyKM1JHiCJFK1BCwnsVqGFbvRJSBjnNYXl7UdQtHq9VrNuCmU2qUanzzFdkxHA4AkHuUbR5k5wpOTtUlQ5xzIK3br/Vf2U6XSrYkhur0VtEZTaV7Sh1kAbSR2Ck7VD6LH11yTQOiPU6rXKmhi06hEX4oQ5JkNFLCBnBUHPhcA74QVE+gOuVLLASWzO4Ea9RFggZrAObFZ15W0NkGWDlfgGvHjGey6f65dO7El1Ol3uaTIqdMuCKqNDbalEBmcUbo6QSFfoVgKG0AbcZGBxrYXxc9pezBZNMpFHoseoXLNby69tAUtYAKsKwdjacjCRnuCQSVK1Mb3pkCg2Za9nOzUuTaGy3Uw1nzpLOG21qxnykqWMepBx21WftndL6/f0Gh3zaKUVpIigupjqH6VKkpwpHOD8Pbud3HIwcg64yVFJbS3jzOqBaTvtmgdVZ1tPMHEc20bvj3ujX5xnyrR6c9Sun3U3pTT3L0rVvS59Ty3IpLz7XjNu7yEtob4Xu4BCgM/tAj0z+hNswbHvW9bXR4q5BVFmRpDis+NCUHA2n6qQsPAn13DXIvsz9Dr3qvUqkVisUKfSKdTJSZKlS2iy4taDuQAhXm27gCSQAQCAckDXSVe6iwKR7TkZTLyTTWoLdCmuZyAorUsK/6VrSD+CtdGCZjpC2M21oAu7zmxdm6FfZZXMdw9WCbxr27du66G00010FkTTTTQhNNNNCE1x91rrcm/wDqo8xBJXTaYswY68+QqCvOQTwSpflAHJwNddVCOqXAkREyX4qnmlNh9ggONEgjckkEBQzkZBGR2OuWL46C3PbgVJtzw7kpqRj3dSQmQhP+Hso/VJB+nppUoJGE6EgHKt+n9L1UGDTX7OrxoFfjQ248pwsh+NPCck+O1kbjlSsLBChn1HGvdLfWKRllUiwKbuyl2fHbkvuIH3ktK2jPrhSyNUx0w6wV+2VmlVlqdVqXFWGnI0glM6CfuBRwVgfcX5hwAcADXSFpXLRbqpAq1BqDcyOvhwIJCm1eqFozlCh8j/DUN4u0h4c3ajsTp9Ap9OU67Nfq9XnTWHqjUpZBckBKsFIA4S2lJVhA4H1768XLNuO2Jchzp1XadHgyFqdVQqswtyIhajlSmVoIW0CSTtwpOTwB21PwkjaPMdquOVdv3/x02k5+LzHn4u3054/LUNgY17ngZNX+FBlcWhp0FXyqT1QraVQarX7ctmmkjxlUFt16WtPqlLroSlon7wQojGqK9oDp9Atm6I8ahM4hz4HjxmUrK3CtohLw77iVBSHNx5JCwNWd1N64QaaHaXZRYqlRTlDk9SiqJHP0wf0yx8hx65OMapOg0G9OpVXkTabGl1qS6vbKrM47WkH7qVEbU4+6gEjjgDGqvr6Qmxhw9RwF017P14qvDp3EdluBVUpx9ynDPKlIHlcP+NO1R9N24DtqwtVn0T6XPWB73Nm15+oTpzaUPtIG2OnaeCAfMpQ5G4kcHGNWZp7brKzvrkaTTTTVlVeEh59v9VEW9+C0j+J1gP1GrI/V2++7+ElofxOvi9Lkp9qW+/WKiSUN4S22n4nXD8KE/U/+gCfTVOyL56sS6Q9eESFFh0Js7ggtIKSgEDPmO9Y55UMZ5xjTY4HSCxhc3rfi0HRu4OBcaumi6HufYK2nKxcSfhs+Sv8A75gfzax3K/dafgsOUv8AzKOP5tZdn3JHrllwLjkFuGiQ0FO71gIbWFbVDJ9NwIB9eNfMK9bSmyH2I1w05xyOkrdAeA2pHc5PGBpZjdZHstjergLWu5D1CxnahN80SReKAqtdKZK5SEbG5jNVjNyG0/ILCskcnynI57aqpfT/AKi2bU1XHb7MyA+hSW2/EkMKdfSf92sIUW3BnjCtv0IONdKVe5qHSZ8CDOqDbcioLCYyACoryQAeOwJIGTxk62UoMe7rMkI8FI3qK+wxzn8sZ1nngkcz0GndjWFqh6qPkWnIGxelSlodfqEqE/FvWI/RavDQS4lEZxSHyPRKcbm15yNiwB8lHnENuG6746wSFUugQXqZbbzgYKN20SOPhddHxccltGQB8Rxzq867Ren1301i5KrBpNTiMJ8ZE1aQQEp75UO4GOx/dqQ0n7KkU6JIpSYi4YRmKqOE+GEkY8uOB8uNE0UrmENNH3r+/wA1rztTF1EPIEZ77/3C5/svpTOpS0P16w6hWXEfCx9pRWowGeAUBZKvTIJIPqDq3odauePHbjMdOX4zDSQhttuoxUpQkDAAAVgAfLX7et9ItefFiOWzXqiZb7caO5DQyUuvLBIQne4kkgJJJxgAHJ1tLWrVSrCpJnWvU6G21tDZnOMlTxOc4DS14AwOTjOeM4OGNZx0queXbWM3W7mV8dlSUf5hHP8ANrJaqlcUcLtd9A+fvjJ/11u9NWpVvwsFiXOXjxKU61+LyD/A6zUklIJG0/LX7pqVCpfrcput9SLYtebLbjU0AyJKnHAhIBJ3ZJ4zsQQPqr66yepdzMXJHa6eWKWqhIlBCZD0chTEdhJHBUOMdskdhx3ONZPWizp9Sr9LuWBRW681HQWJtOU5sLiOSFA5BOMnsc5CeCM686Lbd0VmGqlM0SJYdvO/7S3GWlc2WnHYqHYYyCVc4OMEa3Nczg03r9/teQmi6k9RPHxPrIyAbLaGAfpA2CSbGcKN1tce5qpb/Sq25Kl0SCQibNSnh9TQy4oHkHHJ+RWsegGtj1usm3YdKtunW/S4sKoSqgmG34ScLcaUhW4qPdZCtnKiTyfmdSiv27NtetUCt2lQxOhU2I7Bfp7LgQ54SyFb0lR8ytwyfU5+uRo6jB6gV++KZX3aGKe0hl9mntOvpX7gVBIL7w7FRClEJTzlCc4xnQ1+QQaA/arP0dRyRyxlz3Fow00G4+k+wz3sna8btgqRcLVXto08M2nGZhSTNleFHluIO9LAJISFNhW7JPClpHdOl5dWaXWul040tiWidNaMR1BbJRHK+Dlz4eU79uOTjsMHWbU7Yk29d8KWq1pFz0KJTwxDbQpDi48grK3HVNrIBWtWVFYHr9BrV1qzLqnt1G8JFFbFQk1aLN+xUPpUTHYBTtKh5SsjBwD2z6nbobwNF3ZE46uMSNhBBdYcKJoV9QNfYAC73QNrY33FXafQyBbUVO2dUCzBCcd3HDvczj6BQz+GpZa5XTajT7Po4a9yo0FP2k4U5/SKSPDbBH7Z8zivoU/e1WqqnXupvVCEinhmlM0VCnkFzD3gHcApZ2+VTmduE5wNp+RGrnoNEh0KjfZ9PbK8lTjjjyypch1XKnHFd1KUe5/0AGly+loDtnP9rd8N/kTukhFRtpoPuG9h9zvwK74iVKlwbh6nP1uTLjGFR21waOlTicPPlAVJeQM+bana3uHYBz5nWsHWSMZk9ItyeuKilrqVOcbWFLmtpcDYwgcp3lQKQckpIJAyAdrZ3TC3qNY0Kku0Wjt1hMFLcmox4aPE94KCFuIXtCuFKVt7YGAMDjX3ZvT9MGqtV24lQZ1VjQ2IMT3VpTTLDLOdvlKjuWVYUSrONqNuNuTlXo1pmesQlzUx4Fq1BwvTXokdD6ww4rwG90h1aVgeE22pSEEq7EnOCMa8qH1oalsIm1O2ptNgmhCrFxTgWtRU6lpppKBzl1SvITjd8sc6U7pJNaotViTK209JqdOapzryGlJ8NpchxyZtGT5nQ4TuPO8knjAGVc3TCfUq3UqvBq8WI971AlUtsRzsZVFxtS4AfMkDxAkDgFwkgkDAheUrrEmlRXlV+1KnGkR5EpuQ1DIlBpDDLLhWpSBgDMhtBJwArdk8c2DadVdrNAi1CTGTElOIHvEYOeJ7u5jzNlQ4Kknyn5EEemogrpy6LTfprdRZTUZbrJkSFtFbYbQ74pQlJOTlSlrKlElalkqyMJE5pFPjUumsQIiVBppOMqOVLUTlS1HupSiSpSjySSTydCFlaaaaEJpppoQmor1VRUnbMkMU6PLkB11pEtEP9eYxWPFDf94oyPzOpVpqWniQUqeL5sbo7qxShPSqgSKa3U6zNgCnSKo6jwoQx/ZYzadrLZxxkAknHz+mptppqXOLjZUdPA2CMRt0P+n/ACmmmmqpyaaaaEJpppoQv//Z
'@

$IconBase64 = @'
AAABAAEAOToAAAEAIACgNQAAFgAAACgAAAA5AAAAdAAAAAEAIAAAAAAAqDMAAHQSAAB0EgAAAAAAAAAAAAD//v7///7+///////+//7//v/////+/v/9/v7///3+//7+/v/8/v7///7+//3+/v/8/////f/+//v//f/9/v7//f79///+/f////7//f38///+/v/q9fj/0PH1//b7/v/////////+/+Hk5/+dpKn/YGpz/5CWn//d3eL/+vv8///////++/7/1PX1/9b19f///v7/8v77//v9/P/8/f3//v/+///+/v/+/v7//v7+/////////v7///7+//7+/v/+/v7//v7+//7+/v/////////////////////////////////8/v3//f79//z+/f/8/v3//P79//3+/v/8/f3/+/79//z+/f/6/v3/+/79//z+/P/8/vz/+P7+//v8/f/9+v7/9/76//z+9//4/P7//P37//7++v+JzPH/hdP0//v////j5un/pay2/11ldv86Q1T/NEBU/zhAV/9WXG//mqCq/9/g4v////z/nODz/2zF7f/5+fr//P77//b5/P/4+v3/+/78//z9/v/8/f7//P3+//39/v/9/f7//f7+//z+/P/8/vz//P79//z+/P/9/vz//P78//3+/f/8/v3//P7+//z+/v/////////////////////////////////////////////////////////////////////////////////////////////////9///////+/7nj8v8ht/v/WcXz/7e1uP9janz/OERe/zJHW/85Rlr/Pkhf/zxGXf8+SFz/PUZZ/1xgcv+jqbL/dsvv/yWw+P+f2PL//v/+///////////////////////////////////////////////////////////////////////////////////////////////////////b3eD/2tzf/9nb3f/X2tz/19nc/9XY2v/U19n/09Xa/9LU2P/S1Nj/0dLX/9DS1v/Q0tf/0tLX/87S0//M0tH/zM7U/8zO1P/T1Nb/wd3y/1jE//8eq+r/Ooat/0ZOWv9DTF7/Q05p/zRCWf9jbnb/oaWu/2x0hP85Qlj/Rk9p/0VOaf84R13/P32h/yWk5v82wP7/ruHw/9XY1f/Mz9T/y87U/87P1P/P0tb/0NLX/8/S1v/P0tf/0NPY/9LU2P/T1dj/1NbZ/9XX2v/W19v/19jc/9ja3v/a3N7/293f/9ze4f+QmKL/jZWf/4mSm/+Gj5j/hIyV/4CJkv99hpD/eoKP/3d/jf91fov/dH2K/3F6h/9weYb/dHeI/2h2hP9kdn//dXaI/3d7i/9ceIv/RZTG/zeOxf87Z4b/RFhu/01cdf9AUF//O0pb/4CEmP/d4N7//////+Pm6v+Gjpj/P0pa/0BNYv9OXnP/S1hu/0hjgf83ibv/PZnK/2V7jf9zeYr/b3qI/2t0gv9udoT/cXmG/3F5hv9ye4r/dH2M/3Z+i/95gY3/e4OO/36Gkf+AiZT/g4yX/4aPmv+Kkpz/jpag/5GZo//Q1Nn/ztLX/83R1v/M0NX/y8/T/8nN0//JzNL/x8zQ/8bL0P/Eyc//xsrQ/8TJz//DyMz/w8bO/8HH0v/Iztb/zcrQ/4+Smv8+ZX7/N2SA/05aaf9WXmv/Ully/zhCX/9SW2z/sLOy//f4+f//////9vb4///////5/fr/r7e6/1Fcav86QVn/Wlpw/1pdb/9QV27/QGSE/0Blgv+ChJH/vsPI/83R1//FyM//w8fM/8XIzv/GytD/xsrR/8XJ0P/Hy9D/x8vQ/8jM0f/JztL/ys/T/8zQ1f/N0db/ztLX/8/T2P/////////////////////////////////////////////////////////////////////////////////Gzs//io+Z/1xgc/9MWXP/V2Ny/2Roc/9LU2f/PkJZ/3OBiv/S1tn///////3+/P/3+fr/+Pf8//r4+//9/P///////9LV2P9zeoX/NT9X/0BTaf9ZaHT/WGJv/05hbv9bZnD/gYaS/7rAxP/5/P3////////////////////////////////////////////////////////////////////////////7/f3//P7+//v+/v/8/fz//P7+//v9/f/7/f3/+/z9//v8/P/5+/v/+/z7////////////ys7N/3yDkP9CVGr/OUlf/09ZcP9ea3//VWN7/zdEW/9OUmb/qqiw/+zy8f//////+/v9//f5+P/4/Pz/+Pz8//z9+//6+vn//Pz7///////q7u7/l6Cn/0VLXv88Rln/T2N2/19nfP9QXnH/Q1Bj/0pWaf9weob/uLzB//f4+P//////+/z8//v7+//8/P3//P39//39/f/9/f3/+/39//3+/v/8/v7//P7+//z+/v////7//v/+//3////8/////P////7+/v/9/v7//vz8//79/P///////////8/W2f+Dipb/UFln/0hQYP9MXW//XG59/2Fwgv9JVmn/PEFT/291g//Kz9b////////////3+Pr/+fz7//n7+f/5/P3/+Pv7//r9+//6/Pr/+vz7//j6+////////P78/7/Dy/9eYXb/NT5U/0pWcP9dan//YWp6/1Zdcv9JWWv/S1xs/3mBjf/HyMv////9///////+/v3//fz8///9/v///v///v7///7///////7////+///////9/////f////3////9//7//f79//79/f/+/fv////////////a3eH/jZKd/1Faa/9FUGf/U11y/11oef9ib4P/WGV7/zxHW/9FTl3/m6Gp/+vs7v//////9/v8//f5+f/4+vr/9/r6//f5+//5+/z/9/j5//r8/P/3+fr/9/n6//n7+//3+Pn/+/z9///////d4eb/gIeV/zpDVf9ATF//WGN3/2Jre/9bZnL/VGJy/0VSaf9HUWX/gYaS/8vP1P/+//////////7+/f/+/vv//v/+///+///+/////v/////////7/v///f///////v/+/vv//v78////////////4eXl/5abo/9XW27/O0Fa/z5HYP9WYnb/YW9//2Bsgv9OVXT/OT5a/2Vtef/Gzc7/+Pv8//3////5/P3/9Pb3//n7+v/6/Pz/9vj4//n7/f/5+/z/9ff4//r8/f/4+vv/9ff3//v9/P/4+fr/9fb5//v9/f/+////8vT1/6yxuP9NU2X/NENX/0tcbv9ha3z/YWd6/0hTaf81Q13/NUFf/0xTaf+Hi5j/09jc/////////////v79//38/v/8/////f////3+/v/9/v7//v38///+/P///////v7+/+Xo6/+co6z/WF9w/z1EW/88Q1//Pkdj/05Zbv9hb3z/W2p6/z9MY/9CSV7/kZWi/+jq7v/8//7/9vr5//v9/v/4+fn/9Pf1//v9/P/5+/v/9Pb2//n7/P/5+/z/9Pb3//j6+//8/v7/9vj4//f4+P/6/P3/9/n7//f39//7/Pn//v77//39/v/P09n/Z3J+/y9BVf8/TW3/W2SB/2VsfP9TW2n/PUli/zlEX/88RFr/T1dn/46TnP/c3eL//f39///////9/////f79//7+/f///vz///////7+/v/q7O//pKq0/1licf86RVn/OkVd/z5JYf9FUWj/WWV7/2Vxhf9TXXD/OUJY/1ljc/+9xcf/+Pn5///////3+Pj/9fn4//3+/v/7+/r/9vj3//v9/f/7/fz/9vj5//n7/P/7/f3/9/n6//n7/P/7/f3/+Pr6//j6+f/7/v3/+Pz6//n5+f/+/f3/+/n5//n5+v//////6+7v/5CXof9ARl7/OUNe/1Rgcv9mcoD/XWd5/0dTaf89SWH/PEVf/zxDW/9UWGr/lpqj/+Dj5v/8/P3//////////f/6+/v/7u/x/6+0vP9gaHb/O0VY/zpGW/8+S2D/QU5i/09ecP9jcoT/YG5//0RNYf8/RVz/hYmZ/+Pn7P//////9fjy//T08v/9/f7/+/39//L08//19/b//P////j7+//z9fX/9/n5//z+/v/2+Pj/8/X1//n8/P/8/v7/9ff3//T29v/7/f3/+/z8//T19f/29/f//f3///b3+P/x9PP//v////38/f+/vsH/WWBs/zBAVv9AUWn/YW1+/2Vxg/9RXnT/QU1m/z9KZP89R17/PERX/1ZdbP+coqz/5Ofr//n6+v/Fy9H/Z296/ztGWP85Rlv/Qk1k/0VPZv9MVWr/XWp8/2d2if9RX3P/OENW/1Rda/+zucH/+Pr6///////8/f7/+Pj6//n5+f/7/Pz/+fz8//f4+P/4+vr/+f3+//b6+//1+Pn/+fv8//z+/v/4+fn/9ff4//z9/v/9/v//+fr7//b4+P/6/Pz//fv9//j6+//3+/r/+Pz8//b7+v/3+fv/+vv9//7+/f/9/v3/2+Dj/3Z/jP84Qlj/OkZb/1Ridf9ndYf/XW1+/0paav9BUGL/QU1j/ztFXv86Q1j/WmJx/7G3vv+7wcb/PUZV/z9MYf9EUGb/QEpe/0lUaP9kcIX/Ym+E/0ROYv89Rlb/fYON/93h5f//////8/Xz//Lx8P/8+vz///////r8/f/w8/T/8fP1//r9/v/6/v//8vb7/+vx9f/0+Pn/+/7+//v7/P/y9fL/7fX2//v8/f/+//7/+/z7/+318f/w9fX///z9///////3+ff/7/Hw//X49//8////9vv7/+3x8f/y9vP///////b4+P+ip6//TVJl/zc/VP9IUmj/YW6E/2VzhP9LWWb/P0tc/0RQaf9EUWn/OEFS/52jqf/5+fn/cnmF/zdDWP9TXnP/Vl5y/01YbP9KVmz/QU1g/1JaaP+qrbT/+Pn7//39/f/1+vn/+Pv5//r8+v/8/vz//P79//n6+v/5+Pv/+/r9//z9/v/9/f7/+vr7//f59v/5+/b//v38//79/f/6+/f/8Pn6//j7/P/+/v7//P38//P8+v/2+vr/+fr3//v9+f/9/Pr//Pv7//v6+//4+vz/9/r6//v8/P//+vv///v7//z8/P/9////zMrT/2lse/87RFn/Q01n/01YbP9VYG3/Xml3/1tmff89SmH/XGRx/+zt7///////trrC/zpEWP9HUmn/YWuB/3R+kv9hbH3/V2Bt/83T2P//////+vv7/+7w8P/s8PD/8/j4//n////4/f7/8fb2/+vv7//v8vL/+Pr5//v+/P/4+/r/8/Pz//Dv7v/19vT/+v38//r9/v/59vb/6/Dw/+vy9f/6+vv//f7+//r9/f/z9PX/6PDv/+709P/3+/z/+v3+//X2+f/s7fH/7PDx//X6+f/7+///9/X8/+nu8f/q8vH//f/+/+To6/+Bh5L/PEVZ/19pff9+iZj/Y2+A/0ZUav8zPlH/nKOr//////////7/6uvu/2Rse/80P1b/QEth/09abf+CjZv/d36H/93e4P//////+fr4//n6+f/2+fn/9fj5//r7/P/7/P3/+vz8//r9/P/8//3////9///////5/f3/9/f5//j3+v/3+Pr/+P38//f9/f/7+fn/3+7v/9rv8v/7+/z/+/79//z8/P/5+Pn/9fb5//b4+v/8/f////////7////8/v7/+P37//f9+//4/P3/9vj7//T5+P/z+vj/9Pr3//////+nqq//RU9g/4WMof9SW2//O0Za/zdEV/9SWmj/2dzg/////////vz//f39/6istP85Q1b/Q09l/zdCWP9OWWn/b3iD/5ufpf/////////8///////8/v7//v/9////////////9/j5/+fo7P/e3uX/4OLq/+/v8/////////////////////r//f36//7+/v//////tdvn/73l7P///////P78//v9+//////////////////3+Pj/5+nr/97g4//h4+f/7+/y////////////////////+////v3///////P19f9nbnX/WmR0/2dwhv84QFf/SVNo/zU/Uv+NlJz/+Pn5/////v/+//r//////+Dh5P9bYXD/N0Na/0ZSav8+Sl//Ym2A/3F4g//p6+v////+//z9+////////v///9Lb4P+Zo6v/bXWC/1dfcf9PV27/UVly/2Fmef+EiJX/uL3F/+7z9f//////+/z9//38///3/v//f8Xj/5nS6v////3//P38////////////09re/5miqf9rdoD/VmFu/1Baav9RWm//YWd1/4SKj/+2v8L/7vX1///////8/fz//////8XHzf9GTlz/Z3OE/0pWbP9FTWP/QUld/0lSYv/Kz9P///////79+//8/vv///79//v7/P+ZnKb/NUFW/0BOZ/87S2T/SVdy/11neP+xtLj////////////x8/H/lJyl/0JQY/89Slr/YGp4/4CIlv+KkZz/iY+Z/3N9hv9PWmr/OkRb/2Rsgf/GytH///////7+/f/s+/z/VbTq/3zA5f////r//////+zy8f+Um6b/RlFh/z5LWv9fa3n/fYiU/4mSnv+Ij5v/dX2H/05aZf83Rlf/Y25+/8nK0P///////////4mMmf9FT2P/W2p9/z5KX/9JUWb/OD9U/32Fkv/19vf///////7++v/9/f7//f78///////U1tr/Ullq/zpFW/9DT2f/QUlp/01dcP97g4r//////+Xk6f9scXz/OD9R/4CAkv/Iy8//6+3v//////////////////P6+f/a3uH/qKu5/1ZYa/89SVT/pKy1/////f/Y9fr/Naft/2uz4P/9//z/3uTk/2Zyfv84QFH/gIWP/8bL0P/r7fD/+f////3/////////9/r6/9nd4f+nq7r/UFhu/z1DV/+zs77/5+zr/1ticv9PVm3/Slhp/z9OYv8+SGL/RUxc/73Bxv///////v79///+/f///v///f79//z//v/6+vv/io+Z/zlBVf9DTmL/Q0po/z9SYv9dZ3P/uLvF/21ygP8+Rln/r7jB//r4+///////////////+P////3////9/////f///////////+Li5P91fIz/LT9U/6qyrf/J8f//JaDz/1mq4P/I3t3/Zm93/0FIW/+tub7/+fr6///////////////6////+v////7/////////////////4OLn/2x6iP9FSF7/cHeH/0pUaf9OVG3/QlBf/0FQZv8zPlv/cHaC//Hy8f///////f3+///////+//7//v7+//v9/f//////x8nN/0pSZf87R17/QE9n/z9OX/9MU2n/SE1i/0hUYv+7wsn//////////v/6/vj/yvD4/6jg/f+d3v7/ouP6/7rr9v/r+vP////4///////x8fb/eoSK/0JMVv+Dr9D/NK/7/zqg3P9Td4j/TUpb/8XCzv/////////6///89f/T8Pb/q+T3/6Pb//+Z3/7/tur5/+v59v////v//////+/z9P95g43/KzlW/0JMZf9HTmf/QU9j/z1JYv8/RmH/sLO7///////+/v3////////////9//3//v7///79/v////3/+Pn4/3d/jf82QVv/QVBi/0RPY/8/SGH/O0Fb/6WrtP/////////7/+z39v+V1/j/T8H9/zmm7P82ndf/MKPa/za19v9nzPv/x+X3//77/f//////5uXm/2Bhev84d6v/O7v9/yKY2P8rVnn/pqeu//z///////v/6fb2/5fV+v9Sxfj/NK3j/zya2v83pdf/Ornx/2PO/v+35/v//v36///////l7O3/XG96/zlEWP9DTGf/QU1m/zhCW/9laX3/6uvu///////+/v3////////////9//3//f/////////+/vv//////7e8xP9ESmH/QUpd/0dNZf83QV3/bnaJ//P19f//////5fb3/27P+/8zoen/Ilx//xIjMP8TFB3/EBYg/xE2Uf8rg7f/Rrj8/67i/f////r//////7jEzv8rlcz/LbD7/x+R2P9mm7//7+/w////+v/o+Pb/cMz//y6j5f8eXn3/DR8y/w8THv8QGB7/GDlN/yeDuv87vf3/rOT1///++v//////t77A/0ROXf8+SGP/P0tk/zxFW/+ipLD///////3++/////////////7+/v/+//7//P7///7+///+/fz///////Dz9P9scX7/PkJb/0NKYf8+SGT/r7S8///////4/fn/iNb+/yii5f8ZN1H/CAUG/wYAAP8EAAD/BgAA/wYAAP8QDBD/KW+a/0q/+//N8Pf////7/9vy+v9Cu/X/Lqju/yeP1v94uOf/+vz+//3++v+I2fv/Lp/f/xg4Tf8DBQb/BgAA/wMAAP8DAAD/CwAA/w8TGv8jcp7/T8L9/8nr+f////z/9PTz/25yf/85Q13/OkZd/1lgbv/h4eb///////z9+/////////////7+/v///v///f////3//v/+/f///Pz9//////+qr7b/Pkdf/ztEW/9WXXf/3+Dj///////I6vr/Sb/3/xxObP8GAAD/AAEA/wIDBv8KAAr/BQMF/wEFA/8CAAD/DhQc/yqOx/961/7////6/8Xn+v86tvv/MbHz/x+R2/9EoNz/6PL5/9rx//9Ju/P/IVRt/wQAAP8HAQX/DAID/woCAf8IAgP/AwIH/wAAAP8QGSP/JozK/4TZ///8+/P//////5ifqP87RVz/NkNX/5GZoP///////v75//39/f/+/v///////////////v////////7//v/+/////f3////////n6+7/WmV2/zM7VP9zd4r/+/z7/////f+e4P//MJnE/xAZH/8FAAD/AgIF/wMCAv8KAAL/AgIC/wIEAv8FBAT/BAAA/x1WcP9Qxfb/5/n6/7rk9f85tO//K6Pg/yiTz/9LptL/4PD0/5zj//8ulMv/CxMX/wIAAP8JAwT/CAID/wUCAv8DAgP/BwMF/wEBA/8BAAD/GUpx/2LE/f/e8vn//////7rAxf87Rlr/SVRl/9TZ3P///////f36//z+/v/9///////////////////////////////////////////+////////maKp/y06Uf96gI7///////P8+P9/2P//GW6R/wICAP8AAAD/AAIC/wMDAv8HAAD/AwAC/wUBAf8DBAL/CQAA/xMwPP84sOj/vuv+//v//v+zztX/M0tk/3KEmv/m7/P/9f77/3bV/v8kdaX/AwAA/wECAv8GAgL/BgAD/wABAv8DAwL/BgQE/wMEB/8JAAD/FSk+/z2t6P/C8P7//////8bM0P89SFr/gYeT//3////9/f////3///z//v/9//////////////////////////////////////////7+////////3uLj/0VVZv9vfIv//////+r69/9y0vv/G2eI/xocG/8aFxn/AAAA/wADAP8CAQL/AwIC/wkCAP8JAgL/AgAA/wohNP8/pOX/tuf////////T09P/OzxT/4GClP///fv/+f/8/3PQ/v8fbpD/BQAA/wYEAP8EBAH/AQED/wICAf8DAwH/AAAA/wAAAP8HAAD/GCQ1/zmq3/+88f///////8fK0P9GT2D/trvC///////9/P7///7+//7//f/+///////////////////////////////////////////////+/v//+/z8/3OAhv9ibnv//vz+//X8/f+V1/L/grrO/7S0tf+0rLD/Y1tg/wcGBv8AAQT/AQIF/wQEBP8IBgX/AAAA/xI0S/9LsfD/zu3+//////+9ysv/OT9V/3N2if/u8vL//P/+/3fX/v8igar/DQAC/wYDAP8DAwf/AwIG/wUBAf8AAAD/EA0S/yYmKP8TERH/Bi5I/0Wy8v/J7v///////7i7w/9HUGD/zdPX///////+/v7////9//7//v////////////////////////////////////////////7//v/9/f7//f39/5Gdov9NWGn/6ebt//v////j8/j/+P3/////////////7uvt/0RAQv8AAAD/AQQF/wMCCP8GAwj/AQAA/yNkhP9dxvr/6/r7//////+crLD/KzVH/11gcP/h5Of//////6bi+/86n9f/FSEp/wAAAP8JAwf/BQUC/wAAAP8zLzD/nZmg/8bGx/+moZ//Qoqk/1HE9//l9fv//////5edq/9LVmb/4+nq///////8//7////9//7+/v/+///////////////////////////////////////////////+/v3//////8LGzv89Rlz/tbrE///////2//f/+/36//b4+v/4+vv//vv6/3Zybf8AAAD/BgQH/wMAA/8AAAD/GCg2/zCf2f+X3Pv////9//H09v9peo//Pkhb/0hSY/+3v8n//////+L2+P9Tw/r/IW+S/wkGBP8BAAD/AwIC/xEQEf+xtbL/////////////////zO/5/6Lc7v/1/vr/+/n7/2Nqev9oc4H/9vr4/////v/6/v///v/9//3+/v/+///////////////////////////////////////////////9/v3///7//+/v8f9eaHP/cHaF//j2+v/4//r/9vz7//z8/v//////2uLf/z00LP8AAAD/BAAA/woAAP8ZLkD/J4vH/2DG///l9fj//////8DEyf9ASl3/mKOt/2NueP9ocoH/+vr5////+/+k4f7/M7Hx/yNagf8RERj/AAAA/x8YFv/c3dj//f////r4+P/8/fT///r8//j4+v//////xsbN/0VLXP+qs7v////+//79/P/7/v7//v/7/////f/////////////////////////////////////////////////+/f7///3+//7///+Zp6n/NkBT/7a4xP//////+/36//X9+v/B5Pj/WqzX/xJKef8aPV7/EENd/xdhiP8vnNz/Xsz//9Ht+v////7/6/L1/2Nsef9lbHT/9f3//7e9w/89R1b/r7e7///////4+/j/m9z9/zyz+f8oebL/H0tu/xNCYf+bvtD/9v7+//z+/f/3/f3/9/z6///////w8PP/Zm+B/0tUZv/i6Or////////9/P/9/v7///78/////f///////////////////////////////////////////////////v7//v7///n6+/+Pm6P/LjlM/1hgcP/T1tv///////v++P/I5vD/acXx/0O5+/9JsvH/R7fu/1TM/f+S3///3fH6/////v/3/f3/kZqn/zlEXP92fIj/rq23/5mbqf9MVmr/T1tu/8zP1///////+vz3/7bp9P900v//VL37/zmx6v9Xu+X/xOfx//z9/f/2+f3//P/+//n89/+SmZ3/Mj9X/0lSZ//Y3OH///////7//P////////7+/////v////7////////////////////////////////////////////9/v3//////+vu8P9oa3n/QERa/z1FWf9ZZXH/ycvO//////////7/6/z7/9H19v/F8vv/z/H//971+f/7//v//////+jk6/+Eipf/Mz9J/zM4Qf8zM0L/LSs8/ysvPP8uN0H/ND1U/2Blfv/Axs///////////P/r+fr/0PX5/8bz/v/I7fb/5fTz////////////8/Tz/4+Wof87SVr/PUpe/zxFWf+qr7f//v7+//7//f////////7//////v////////////////////////////////////////////7////9/fz//////9PW3P9JUWH/QEpj/0RPaP81QlX/RE5d/5KVo//e3+b//////////f////3////////////p7ev/tb3B/7C0wf+mqrf/XWFp/woLDP8BAAL/AQED/wIEAv8EBQb/ERUa/zI6Rf9TXXL/j5yr/93h3//////////+//////////////////P59v+9v8T/am57/zQ/WP87SGX/RE9p/zlCV/9/hY//+/v7//////////7//v7////+/v/////////////////////////////////////////////////+/v3////+/6mrs/86RVn/QE9p/zZGX/9GU2n/VWyD/zdRbf9AVWr/an2F/5Oeqf+nqrn/oqet/4GKjf+Ij5X/r7a2/36FhP9WVVr/ko+U/5OVmP9JSUn/BQYE/wAAAP8AAAH/AAAA/wwOEP8qKzb/QEdY/1lie/+CgZz/nqeu/6myt/+iqLH/gpCW/1Zmc/86SGP/TFh5/1BddP87SVz/QE9j/zpIXP9aYnH/6ezv///////9//3//f/+///+////////////////////////////////////////////////////////+Pv7/36Dj/88Qlr/O0Vg/0BRaf+InbH/qcji/4inyP9vgZv/Wmd4/0RUZP89TmP/SVZr/4qPnv+qqK7/V1NU/xEREP8BAAD/GRgZ/09PS/+dnZr/nZyg/0hFS/8LCgz/AAAA/wAAAP8FBgT/ERcW/yQnOP81OUz/MkRP/0BHXv9GTWz/TVts/2tzh/94kaz/m77Y/5u1zf9UZHb/O0VZ/z9KYv9CTWD/wsbM///////8/vv//v/+///+///////////////////////////////////////////////+/v//////5uvu/1pgcP81PVj/S1pz/4+luf+xydv/ssvd/87f7f/v8/f/7u/y/+Pn6v/k6er/zdHV/317gP8kISP/BAIC/wAAAP8EAQX/AAAA/wAAAP8WFhb/T05R/56hov+am5f/SEVC/w8PD/8AAAD/AAAA/wIAAf8HBQb/AwgJ/2psb//e3+P/6uzu//P09v/h7ff/ttLi/6rN2f+dtsr/V2SF/zZDXv84Q1j/mp6n///////7//r//f/9///+//////////////////////////////////////////////7+/v//////wcLH/zhBVf9NYXv/mrPG/8LX5P/S4ev/6/P4//n9/P////z///////v7+v+5u7b/QUM+/wgICP8AAAD/CAEA/wMBAf8BAwL/AQIC/wMBAf8AAAD/AAAA/xAQEP9PUVD/nZ6Z/5SUlP9GRkv/FxcX/wUEBP8IBwf/Jygn/4OFgP/5+Pb/////////////////9/n7/9bj7P+61OT/m73N/1NuhP8tPFL/bnOA//r5+/////7//P79//3+//////////////////////////////////////////////7+/v/9/f3/kJSd/15tgP+2y9v/4O/2//b6+//9/v7///7///////////7/19fX/2pra/8LCgr/AAAA/wAAAf8DAgL/AQAA/wAAAP8AAAD/AAAA/wAAAP8BAQH/AgEB/wAAAP8AAAD/CwwL/05OT/+ampr/pKWk/3h4eP9dXV3/RERE/3d3eP/w8PD///////7+///////////+//3////t+fr/2O7w/6/M2f9ab4P/R1Bf/9fX3P///////f3+//z+///+///////////////////////////////////////////////3+Pj/ub/C/97n7f/5/////P7+///+/P/8/vz//P3+/+Xk5P+ZmZn/JiYm/wAAAP8BAAD/AgMD/wEBAf8BAQH/AAAA/wAAAP8AAAD/AAAA/wAAAP8BAQH/AQEB/wEBAf8CAgL/AAAA/wAAAP8ICAf/UVFR/6ipqf/CwsL/fHx8/4qKiv/z8/L//v7+//z//v////7////8//3//f/8////+v////f8///X3eb/doGI/6aws//9////+/38///+/v/////////////////////////////////////////////////7/v3//v////7////+/f7///36///++f//////yc3N/0dISP8AAAD/AAAA/wAAAP8AAAD/AgIC/wICAv8CAgL/AQEB/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8BAQH/AQEB/wICAv8AAAD/AAAA/wUEBP9TU1P/mJiY/8PDw/////////////z//v/8/fv//v78////+////fz///38///+/v//////6e3u/8vU1f/3//7/+//8//3//P////7////////////////////////////////////////////+//7//v/9//z+/f/9//z//v76//7//f///v//ury8/2ZoaP9HR0f/LS0t/xQUFP8AAAD/AAAA/wAAAP8AAAD/AAAA/wICAv8CAgL/AQEB/wEBAf8AAAD/AAAA/wAAAP8AAAD/AAAA/wEBAf8BAQH/AgIC/wAAAP8AAAD/BgYG/0xMTP+goKD/3t3e/////////////P79//z9/P/+/f3///39//z++//7/vz////////////+/f3//P/9//v//f/+//7////////////////////////////////////////////+/v7///7+//3//v/6//3/+v/+//z//v///f/////////////8/Pz/0tLS/6ampv95eXn/TUxM/y0tLf8RERH/AAAA/wAAAP8AAAD/AAAA/wAAAP8BAQH/AQEB/wICAv8BAQH/AQEB/wAAAP8AAAD/AAAA/wAAAP8CAgL/AAAA/wAAAP8AAAD/QD9A/5aVlv/b29v////////////8/v7//Pz8//z9/P/8//3//v7+//37/////P7///7+//7////+/////////////////////////////////////////////////v///v7+//7+/v/9/////P////3//////////f39//7+/v//////////////////////9fX1/8zMzP+lpaX/eXl5/05OTv8uLi7/CwsL/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8vMDD/jY6O/9ra2v/9/////f39//7+/v/+/////f////3////+/v7///7+///+///////////////////////////////////////////////////+/////f////////////////7////+//////7////////////9/f3//f39//z8/P/+/v7//////////////////////+7u7v/Ly8v/pKSk/3p6ev9TU1P/UlJS/1dXV/9ZWVn/YGBg/2VlZf9oaGj/bm5u/3V1df95eXn/fX19/4ODg/+Li4v/jo6O/4eIh/95eXj/hoWF/8vKyv///v7///////7///////////7///////////3//v/+//3////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/////f7+//39/f/+/v7////////////////////////////s7Oz/6+vr/+/v7//x8fH/9vb2//n5+f/7+/v//v7+//////////////////////////////////////////////////38/P/9/f3//v7+/////////////////////////////v////7///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////39/f/9/f3////////////////////////////////////////////////////////////////////////////////////////////+///////////////9/v7///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7+/v/9/f3//f39//7+/v/9/f3//v7+//7+/v/+/v7//v7+//7+/v/9/f3///////39/f////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==
'@

function ConvertFrom-Base64Image {
    param([Parameter(Mandatory)][string]$Base64)
    $bytes  = [Convert]::FromBase64String($Base64)
    $stream = New-Object System.IO.MemoryStream(@(,$bytes))
    return [System.Drawing.Image]::FromStream($stream)
}

function ConvertFrom-Base64Icon {
    param([Parameter(Mandatory)][string]$Base64)
    $bytes  = [Convert]::FromBase64String($Base64)
    $stream = New-Object System.IO.MemoryStream(@(,$bytes))
    return New-Object System.Drawing.Icon($stream)
}

# ============================================================================
#  IMPORTS
# ============================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ============================================================================
#  THEME / STYLES
# ============================================================================
$Theme = @{
    BgDark       = [System.Drawing.ColorTranslator]::FromHtml('#0F1721')
    BgMain       = [System.Drawing.ColorTranslator]::FromHtml('#1A2332')
    BgCard       = [System.Drawing.ColorTranslator]::FromHtml('#243447')
    BgCardHover  = [System.Drawing.ColorTranslator]::FromHtml('#2D4159')
    Accent       = [System.Drawing.ColorTranslator]::FromHtml('#00B4D8')
    AccentDark   = [System.Drawing.ColorTranslator]::FromHtml('#0077B6')
    TextMain     = [System.Drawing.ColorTranslator]::FromHtml('#E8EEF4')
    TextDim      = [System.Drawing.ColorTranslator]::FromHtml('#8B98A9')
    Success      = [System.Drawing.ColorTranslator]::FromHtml('#4ADE80')
    Warning      = [System.Drawing.ColorTranslator]::FromHtml('#FBBF24')
    Danger       = [System.Drawing.ColorTranslator]::FromHtml('#F87171')
    Border       = [System.Drawing.ColorTranslator]::FromHtml('#334155')
}

$Fonts = @{
    Title    = New-Object System.Drawing.Font('Segoe UI Semilight', 20, [System.Drawing.FontStyle]::Regular)
    Subtitle = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Regular)
    Section  = New-Object System.Drawing.Font('Segoe UI Semibold', 12, [System.Drawing.FontStyle]::Regular)
    Body     = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Regular)
    BodyBold = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5, [System.Drawing.FontStyle]::Regular)
    Small    = New-Object System.Drawing.Font('Segoe UI', 8.5, [System.Drawing.FontStyle]::Regular)
    Mono     = New-Object System.Drawing.Font('Consolas', 9, [System.Drawing.FontStyle]::Regular)
    Step     = New-Object System.Drawing.Font('Segoe UI Semibold', 10, [System.Drawing.FontStyle]::Regular)
    StepNum  = New-Object System.Drawing.Font('Segoe UI Light', 22, [System.Drawing.FontStyle]::Regular)
}

# Variable d'état globale
$script:CurrentStep   = 1
$script:Diagnostic    = $null
$script:SelectedActions = @{}

# ============================================================================
#  FONCTIONS DE DIAGNOSTIC
# ============================================================================

function Get-VBSDiagnostic {
    <#
        Récupère l'état complet de la pile virtualisation Windows.
        Retourne un objet structuré avec un statut global et tous les détails.
    #>
    $result = [ordered]@{
        VBSStatus          = 'Inconnu'   # Off / Configured / Running
        VBSStatusCode      = -1
        HVCIRunning        = $false      # Memory Integrity
        CredGuardRunning   = $false
        ServicesRunning    = @()
        ServicesConfigured = @()
        HypervisorBoot     = 'Inconnu'   # Off / Auto
        Features           = @{}         # FeatureName => $true/$false
        RegDeviceGuard     = @{}
        RegLsaCfg          = $null
        HypervisorDetected = $false
        HasIssues          = $false
        IssueCount         = 0
    }

    # --- WMI Win32_DeviceGuard ---
    try {
        $dg = Get-CimInstance -ClassName Win32_DeviceGuard `
            -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction Stop
        $result.VBSStatusCode = [int]$dg.VirtualizationBasedSecurityStatus
        $result.VBSStatus = switch ($result.VBSStatusCode) {
            0 { 'Non activée' }
            1 { 'Activée mais non démarrée' }
            2 { 'En cours d''exécution' }
            default { 'Inconnu' }
        }
        $result.ServicesRunning    = @($dg.SecurityServicesRunning)
        $result.ServicesConfigured = @($dg.SecurityServicesConfigured)
        # Service 1 = Credential Guard, 2 = HVCI / Memory Integrity
        $result.CredGuardRunning = $result.ServicesRunning -contains 1
        $result.HVCIRunning      = $result.ServicesRunning -contains 2
    } catch {
        # WMI peut être vide sur certains hôtes : ce n'est pas bloquant
    }

    # --- BCD hypervisorlaunchtype ---
    try {
        $bcd = & bcdedit /enum '{current}' 2>$null | Out-String
        if ($bcd -match 'hypervisorlaunchtype\s+(\w+)') {
            $result.HypervisorBoot = $matches[1]
        } else {
            $result.HypervisorBoot = 'Non défini (= Auto par défaut)'
        }
    } catch { }

    # --- Fonctionnalités Windows ---
    $featNames = @(
        'Microsoft-Hyper-V-All',
        'Microsoft-Hyper-V',
        'Microsoft-Hyper-V-Hypervisor',
        'Microsoft-Hyper-V-Management-PowerShell',
        'Microsoft-Hyper-V-Tools-All',
        'VirtualMachinePlatform',
        'HypervisorPlatform',
        'Microsoft-Windows-Subsystem-Linux',
        'Containers',
        'Containers-DisposableClientVM'
    )
    foreach ($f in $featNames) {
        try {
            $st = Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction Stop
            $result.Features[$f] = ($st.State -eq 'Enabled')
        } catch {
            $result.Features[$f] = $null  # n'existe pas sur cet OS
        }
    }

    # --- Registre Device Guard ---
    $dgKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    if (Test-Path $dgKey) {
        try {
            $props = Get-ItemProperty -Path $dgKey -ErrorAction Stop
            foreach ($name in @('EnableVirtualizationBasedSecurity',
                                 'RequirePlatformSecurityFeatures',
                                 'HypervisorEnforcedCodeIntegrity',
                                 'LsaCfgFlags')) {
                if ($null -ne $props.$name) {
                    $result.RegDeviceGuard[$name] = $props.$name
                }
            }
        } catch { }
    }

    # --- Registre LSA / Credential Guard ---
    try {
        $lsa = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
            -Name 'LsaCfgFlags' -ErrorAction Stop
        $result.RegLsaCfg = $lsa.LsaCfgFlags
    } catch { }

    # --- Détection hyperviseur actif ---
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $result.HypervisorDetected = [bool]$cs.HypervisorPresent
    } catch { }

    # --- Comptage des problèmes ---
    $issues = 0
    if ($result.VBSStatusCode -ge 1)               { $issues++ }
    if ($result.HVCIRunning)                       { $issues++ }
    if ($result.CredGuardRunning)                  { $issues++ }
    if ($result.HypervisorBoot -match '^Auto')     { $issues++ }
    if ($result.HypervisorBoot -eq 'Non défini (= Auto par défaut)') { $issues++ }
    if ($result.HypervisorDetected)                { $issues++ }
    foreach ($k in $result.Features.Keys) {
        if ($result.Features[$k] -eq $true)        { $issues++ }
    }
    $result.IssueCount = $issues
    $result.HasIssues  = ($issues -gt 0)

    return [PSCustomObject]$result
}

# ============================================================================
#  FONCTIONS D'ACTION
# ============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $color = switch ($Level) {
        'OK'   { $Theme.Success }
        'WARN' { $Theme.Warning }
        'ERR'  { $Theme.Danger  }
        'STEP' { $Theme.Accent  }
        default { $Theme.TextMain }
    }
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $tag = switch ($Level) {
        'OK'   { '[OK]  ' }
        'WARN' { '[!]   ' }
        'ERR'  { '[X]   ' }
        'STEP' { '[>>>] ' }
        default { '[..]  ' }
    }
    if ($script:LogBox) {
        $script:LogBox.SelectionStart  = $script:LogBox.TextLength
        $script:LogBox.SelectionLength = 0
        $script:LogBox.SelectionColor  = $Theme.TextDim
        $script:LogBox.AppendText("$stamp  ")
        $script:LogBox.SelectionStart  = $script:LogBox.TextLength
        $script:LogBox.SelectionColor  = $color
        $script:LogBox.AppendText("$tag$Message`r`n")
        $script:LogBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Invoke-DisableHypervisorBoot {
    Write-Log "Désactivation de l'hyperviseur au démarrage (bcdedit)..." 'STEP'
    & bcdedit /set hypervisorlaunchtype off | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Log "hypervisorlaunchtype = off appliqué" 'OK'
    } else {
        Write-Log "Échec de bcdedit (code $LASTEXITCODE)" 'ERR'
    }
}

function Invoke-DisableFeature {
    param([string]$Name)
    Write-Log "Désactivation de la fonctionnalité Windows : $Name" 'STEP'
    try {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
        if ($f.State -ne 'Enabled') {
            Write-Log "$Name est déjà désactivé" 'OK'
            return
        }
        $r = Disable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -ErrorAction Stop
        Write-Log "$Name désactivé" 'OK'
    } catch {
        Write-Log "$Name : $($_.Exception.Message)" 'WARN'
    }
}

function Invoke-DisableVBSRegistry {
    Write-Log "Mise à zéro des clés Device Guard / VBS dans le registre..." 'STEP'
    $dgKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    if (-not (Test-Path $dgKey)) {
        New-Item -Path $dgKey -Force | Out-Null
    }
    $values = @{
        EnableVirtualizationBasedSecurity = 0
        RequirePlatformSecurityFeatures   = 0
        HypervisorEnforcedCodeIntegrity   = 0
        LsaCfgFlags                       = 0
    }
    foreach ($k in $values.Keys) {
        try {
            New-ItemProperty -Path $dgKey -Name $k -Value $values[$k] `
                -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            Write-Log "$k = 0 écrit dans DeviceGuard" 'OK'
        } catch {
            Write-Log "Erreur sur $k : $($_.Exception.Message)" 'ERR'
        }
    }

    # Sous-clé Scenarios (HVCI)
    $scen = "$dgKey\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (Test-Path $scen) {
        try {
            Set-ItemProperty -Path $scen -Name 'Enabled' -Value 0 `
                -Type DWord -ErrorAction Stop
            Write-Log "Scenarios\HVCI.Enabled = 0" 'OK'
        } catch {
            Write-Log "Erreur scenarios HVCI : $($_.Exception.Message)" 'WARN'
        }
    }
}

function Invoke-DisableCredentialGuard {
    Write-Log "Désactivation de Credential Guard (LSA)..." 'STEP'
    try {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
            -Name 'LsaCfgFlags' -Value 0 -Type DWord -ErrorAction Stop
        Write-Log "LsaCfgFlags = 0" 'OK'
    } catch {
        try {
            New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
                -Name 'LsaCfgFlags' -Value 0 -PropertyType DWord -Force `
                -ErrorAction Stop | Out-Null
            Write-Log "LsaCfgFlags créé à 0" 'OK'
        } catch {
            Write-Log "Erreur LSA : $($_.Exception.Message)" 'ERR'
        }
    }
}

function Invoke-AllSelectedActions {
    Write-Log "================================================" 'STEP'
    Write-Log "Démarrage des opérations de désactivation" 'STEP'
    Write-Log "================================================" 'STEP'

    if ($script:SelectedActions['HypervisorBoot']) {
        Invoke-DisableHypervisorBoot
    }
    if ($script:SelectedActions['Registry']) {
        Invoke-DisableVBSRegistry
    }
    if ($script:SelectedActions['CredGuard']) {
        Invoke-DisableCredentialGuard
    }
    if ($script:SelectedActions['Features']) {
        $featList = @(
            'Microsoft-Hyper-V-All',
            'Microsoft-Hyper-V',
            'Microsoft-Hyper-V-Hypervisor',
            'VirtualMachinePlatform',
            'HypervisorPlatform',
            'Microsoft-Windows-Subsystem-Linux',
            'Containers',
            'Containers-DisposableClientVM'
        )
        foreach ($f in $featList) {
            Invoke-DisableFeature -Name $f
        }
    }

    Write-Log "================================================" 'STEP'
    Write-Log "Opérations terminées." 'OK'
    Write-Log "Un redémarrage est INDISPENSABLE pour appliquer." 'WARN'
    Write-Log "Au redémarrage, si un écran demande F3, APPUYEZ !" 'WARN'
    Write-Log "================================================" 'STEP'
}

# ============================================================================
#  FABRIQUES DE CONTRÔLES
# ============================================================================

function New-Card {
    param([int]$X, [int]$Y, [int]$Width, [int]$Height)
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point($X, $Y)
    $p.Size     = New-Object System.Drawing.Size($Width, $Height)
    $p.BackColor = $Theme.BgCard
    return $p
}

function New-Label {
    param(
        [string]$Text, [int]$X, [int]$Y,
        [System.Drawing.Font]$Font = $Fonts.Body,
        [System.Drawing.Color]$Color = $Theme.TextMain,
        [int]$Width = 0, [int]$Height = 0
    )
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X, $Y)
    $l.Font = $Font
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    if ($Width -gt 0) {
        $l.Size = New-Object System.Drawing.Size($Width, ($(if ($Height -gt 0) {$Height} else {25})))
    } else {
        $l.AutoSize = $true
    }
    return $l
}

function New-PrimaryButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width = 140, [int]$Height = 38)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X, $Y)
    $b.Size = New-Object System.Drawing.Size($Width, $Height)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $Theme.Accent
    $b.ForeColor = $Theme.BgDark
    $b.Font = $Fonts.BodyBold
    $b.Cursor = 'Hand'
    $b.Add_MouseEnter({ $this.BackColor = $Theme.AccentDark })
    $b.Add_MouseLeave({ $this.BackColor = $Theme.Accent })
    return $b
}

function New-SecondaryButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width = 140, [int]$Height = 38)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X, $Y)
    $b.Size = New-Object System.Drawing.Size($Width, $Height)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = $Theme.Border
    $b.BackColor = $Theme.BgCard
    $b.ForeColor = $Theme.TextMain
    $b.Font = $Fonts.Body
    $b.Cursor = 'Hand'
    $b.Add_MouseEnter({ $this.BackColor = $Theme.BgCardHover })
    $b.Add_MouseLeave({ $this.BackColor = $Theme.BgCard })
    return $b
}

function New-StatusBadge {
    param(
        [string]$Text, [int]$X, [int]$Y,
        [System.Drawing.Color]$Color
    )
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X, $Y)
    $l.Font = $Fonts.Small
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.AutoSize = $true
    return $l
}

# ============================================================================
#  CONSTRUCTION DE LA FENÊTRE PRINCIPALE
# ============================================================================

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Easyformer · Reset VBS — Préparation TP VMware Workstation'
$form.Size = New-Object System.Drawing.Size(1080, 740)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $Theme.BgMain
$form.Font = $Fonts.Body
$form.ForeColor = $Theme.TextMain
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
try { $form.Icon = ConvertFrom-Base64Icon -Base64 $IconBase64 } catch { }

# --- SIDEBAR ---
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Location = New-Object System.Drawing.Point(0, 0)
$sidebar.Size = New-Object System.Drawing.Size(280, 700)
$sidebar.BackColor = $Theme.BgDark
$form.Controls.Add($sidebar)

# --- Boîte logo Easyformer (fond blanc) ---
$logoBox = New-Object System.Windows.Forms.Panel
$logoBox.Location = New-Object System.Drawing.Point(20, 25)
$logoBox.Size = New-Object System.Drawing.Size(240, 110)
$logoBox.BackColor = [System.Drawing.Color]::White
$sidebar.Controls.Add($logoBox)

$logoPic = New-Object System.Windows.Forms.PictureBox
$logoPic.Image = ConvertFrom-Base64Image -Base64 $LogoBase64
$logoPic.SizeMode = 'Zoom'
$logoPic.Location = New-Object System.Drawing.Point(10, 8)
$logoPic.Size = New-Object System.Drawing.Size(220, 94)
$logoPic.BackColor = [System.Drawing.Color]::White
$logoBox.Controls.Add($logoPic)

# --- Ligne accent ---
$sep1 = New-Object System.Windows.Forms.Panel
$sep1.Location = New-Object System.Drawing.Point(30, 155)
$sep1.Size = New-Object System.Drawing.Size(40, 2)
$sep1.BackColor = $Theme.Accent
$sidebar.Controls.Add($sep1)

# --- Nom de l'outil ---
$toolName = New-Label -Text 'Reset VBS' -X 30 -Y 170 `
    -Font $Fonts.Section -Color $Theme.TextMain
$sidebar.Controls.Add($toolName)

$toolSub = New-Label -Text 'Préparation TP VMware Workstation' -X 30 -Y 195 `
    -Font $Fonts.Small -Color $Theme.TextDim
$sidebar.Controls.Add($toolSub)

# --- Séparateur fin ---
$sep2 = New-Object System.Windows.Forms.Panel
$sep2.Location = New-Object System.Drawing.Point(30, 225)
$sep2.Size = New-Object System.Drawing.Size(220, 1)
$sep2.BackColor = $Theme.Border
$sidebar.Controls.Add($sep2)

# Étapes (4 entrées cliquables visuellement)
$stepsData = @(
    @{ Num = '01'; Title = 'Diagnostic'; Sub = 'État du système' },
    @{ Num = '02'; Title = 'Préparation'; Sub = 'Actions à mener' },
    @{ Num = '03'; Title = 'Exécution'; Sub = 'Application en direct' },
    @{ Num = '04'; Title = 'Finalisation'; Sub = 'Vérification & reboot' }
)

$stepControls = @()
$yStep = 245
foreach ($s in $stepsData) {
    $row = New-Object System.Windows.Forms.Panel
    $row.Location = New-Object System.Drawing.Point(20, $yStep)
    $row.Size = New-Object System.Drawing.Size(245, 70)
    $row.BackColor = $Theme.BgDark

    $num = New-Label -Text $s.Num -X 10 -Y 14 -Font $Fonts.StepNum -Color $Theme.TextDim
    $title = New-Label -Text $s.Title -X 70 -Y 16 -Font $Fonts.Step -Color $Theme.TextDim
    $sub = New-Label -Text $s.Sub -X 70 -Y 40 -Font $Fonts.Small -Color $Theme.TextDim

    $row.Controls.AddRange(@($num, $title, $sub))
    $sidebar.Controls.Add($row)

    $stepControls += @{ Panel = $row; Num = $num; Title = $title; Sub = $sub }
    $yStep += 80
}

# Crédit / signature en bas de sidebar
$credit = New-Label -Text 'v1.1  ·  easyformer.fr' -X 30 -Y 660 `
    -Font $Fonts.Small -Color $Theme.TextDim
$sidebar.Controls.Add($credit)

# --- ZONE PRINCIPALE ---
$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Location = New-Object System.Drawing.Point(280, 0)
$mainPanel.Size = New-Object System.Drawing.Size(800, 700)
$mainPanel.BackColor = $Theme.BgMain
$form.Controls.Add($mainPanel)

# Fonction pour mettre à jour la sidebar selon l'étape active
function Update-Sidebar {
    param([int]$Step)
    for ($i = 0; $i -lt $stepControls.Count; $i++) {
        $c = $stepControls[$i]
        if (($i + 1) -eq $Step) {
            $c.Panel.BackColor = $Theme.BgCard
            $c.Num.ForeColor   = $Theme.Accent
            $c.Title.ForeColor = $Theme.TextMain
            $c.Sub.ForeColor   = $Theme.TextMain
        } elseif (($i + 1) -lt $Step) {
            $c.Panel.BackColor = $Theme.BgDark
            $c.Num.ForeColor   = $Theme.Success
            $c.Title.ForeColor = $Theme.TextDim
            $c.Sub.ForeColor   = $Theme.TextDim
        } else {
            $c.Panel.BackColor = $Theme.BgDark
            $c.Num.ForeColor   = $Theme.TextDim
            $c.Title.ForeColor = $Theme.TextDim
            $c.Sub.ForeColor   = $Theme.TextDim
        }
    }
}

# ============================================================================
#  PANELS DES ÉTAPES
# ============================================================================

function Clear-MainPanel {
    $mainPanel.Controls.Clear()
}

function Add-PanelHeader {
    param([string]$Title, [string]$Subtitle)
    $titleLbl = New-Label -Text $Title -X 40 -Y 30 -Font $Fonts.Title -Color $Theme.TextMain
    $subLbl   = New-Label -Text $Subtitle -X 42 -Y 72 -Font $Fonts.Subtitle -Color $Theme.TextDim
    $line = New-Object System.Windows.Forms.Panel
    $line.Location = New-Object System.Drawing.Point(40, 100)
    $line.Size = New-Object System.Drawing.Size(60, 2)
    $line.BackColor = $Theme.Accent
    $mainPanel.Controls.AddRange(@($titleLbl, $subLbl, $line))
}

# ---------------------------------------------------------------------------
#  ÉTAPE 1 : DIAGNOSTIC
# ---------------------------------------------------------------------------
function Show-Step1Diagnostic {
    Clear-MainPanel
    Update-Sidebar -Step 1
    Add-PanelHeader -Title 'Diagnostic du système' `
                    -Subtitle 'Identification des composants qui empêchent VMware Workstation de lancer une VM imbriquée (ESXi, etc.)'

    # Lance le diag (peut prendre 2-3s)
    $loading = New-Label -Text 'Analyse en cours...' -X 40 -Y 130 -Color $Theme.TextDim
    $mainPanel.Controls.Add($loading)
    [System.Windows.Forms.Application]::DoEvents()
    $script:Diagnostic = Get-VBSDiagnostic
    $mainPanel.Controls.Remove($loading)

    $d = $script:Diagnostic

    # === Carte 1 : VBS / Hyperviseur global ===
    $card1 = New-Card -X 40 -Y 125 -Width 720 -Height 145
    $mainPanel.Controls.Add($card1)

    $card1.Controls.Add((New-Label -Text 'Sécurité basée sur la virtualisation (VBS)' `
        -X 20 -Y 15 -Font $Fonts.Section -Color $Theme.TextMain))

    $vbsColor = if ($d.VBSStatusCode -eq 0) { $Theme.Success } else { $Theme.Danger }
    $vbsIcon  = if ($d.VBSStatusCode -eq 0) { '●' } else { '●' }
    $card1.Controls.Add((New-Label -Text $vbsIcon -X 20 -Y 50 -Font $Fonts.Section -Color $vbsColor))
    $card1.Controls.Add((New-Label -Text "État VBS : $($d.VBSStatus)" `
        -X 45 -Y 52 -Font $Fonts.Body -Color $Theme.TextMain))

    $hvColor = if ($d.HypervisorDetected) { $Theme.Danger } else { $Theme.Success }
    $hvText  = if ($d.HypervisorDetected) { 'Hyperviseur Windows détecté en mémoire' } else { 'Aucun hyperviseur Windows actif' }
    $card1.Controls.Add((New-Label -Text '●' -X 20 -Y 80 -Font $Fonts.Section -Color $hvColor))
    $card1.Controls.Add((New-Label -Text $hvText `
        -X 45 -Y 82 -Font $Fonts.Body -Color $Theme.TextMain))

    $bcdColor = if ($d.HypervisorBoot -eq 'Off') { $Theme.Success } else { $Theme.Warning }
    $card1.Controls.Add((New-Label -Text '●' -X 20 -Y 108 -Font $Fonts.Section -Color $bcdColor))
    $card1.Controls.Add((New-Label -Text "Démarrage hyperviseur (BCD) : $($d.HypervisorBoot)" `
        -X 45 -Y 110 -Font $Fonts.Body -Color $Theme.TextMain))

    # === Carte 2 : Services VBS détaillés ===
    $card2 = New-Card -X 40 -Y 285 -Width 350 -Height 145
    $mainPanel.Controls.Add($card2)
    $card2.Controls.Add((New-Label -Text 'Services VBS' `
        -X 20 -Y 15 -Font $Fonts.Section -Color $Theme.TextMain))

    $hvciColor = if ($d.HVCIRunning) { $Theme.Danger } else { $Theme.Success }
    $hvciText  = if ($d.HVCIRunning) { 'Intégrité mémoire (HVCI) : active' } else { 'Intégrité mémoire (HVCI) : inactive' }
    $card2.Controls.Add((New-Label -Text '●' -X 20 -Y 50 -Font $Fonts.Section -Color $hvciColor))
    $card2.Controls.Add((New-Label -Text $hvciText -X 45 -Y 52 -Font $Fonts.Body -Color $Theme.TextMain))

    $cgColor = if ($d.CredGuardRunning) { $Theme.Danger } else { $Theme.Success }
    $cgText  = if ($d.CredGuardRunning) { 'Credential Guard : actif' } else { 'Credential Guard : inactif' }
    $card2.Controls.Add((New-Label -Text '●' -X 20 -Y 80 -Font $Fonts.Section -Color $cgColor))
    $card2.Controls.Add((New-Label -Text $cgText -X 45 -Y 82 -Font $Fonts.Body -Color $Theme.TextMain))

    $svcText = if ($d.ServicesRunning.Count -gt 0) {
        "Codes actifs : $($d.ServicesRunning -join ', ')"
    } else { "Aucun service VBS en cours" }
    $card2.Controls.Add((New-Label -Text $svcText -X 20 -Y 115 -Font $Fonts.Small -Color $Theme.TextDim))

    # === Carte 3 : Fonctionnalités Windows ===
    $card3 = New-Card -X 410 -Y 285 -Width 350 -Height 235
    $mainPanel.Controls.Add($card3)
    $card3.Controls.Add((New-Label -Text 'Fonctionnalités Windows' `
        -X 20 -Y 15 -Font $Fonts.Section -Color $Theme.TextMain))

    $yf = 50
    $featDisplay = @(
        @{ Key = 'Microsoft-Hyper-V-All';                    Display = 'Hyper-V (complet)' }
        @{ Key = 'Microsoft-Hyper-V-Hypervisor';             Display = 'Hyper-V Hypervisor' }
        @{ Key = 'VirtualMachinePlatform';                   Display = 'Virtual Machine Platform' }
        @{ Key = 'HypervisorPlatform';                       Display = 'Windows Hypervisor Platform' }
        @{ Key = 'Microsoft-Windows-Subsystem-Linux';        Display = 'WSL' }
        @{ Key = 'Containers';                               Display = 'Conteneurs' }
        @{ Key = 'Containers-DisposableClientVM';            Display = 'Windows Sandbox' }
    )
    foreach ($fd in $featDisplay) {
        $st = $d.Features[$fd.Key]
        if ($st -eq $null) { continue }
        $col = if ($st) { $Theme.Danger } else { $Theme.Success }
        $tag = if ($st) { 'ON ' } else { 'OFF' }
        $card3.Controls.Add((New-Label -Text "● $tag" -X 20 -Y $yf -Font $Fonts.Small -Color $col))
        $card3.Controls.Add((New-Label -Text $fd.Display -X 70 -Y $yf -Font $Fonts.Body -Color $Theme.TextMain))
        $yf += 24
    }

    # === Carte 4 : Synthèse ===
    $card4 = New-Card -X 40 -Y 445 -Width 350 -Height 75
    $mainPanel.Controls.Add($card4)

    if ($d.HasIssues) {
        $card4.Controls.Add((New-Label -Text "$($d.IssueCount) anomalie(s) détectée(s)" `
            -X 20 -Y 15 -Font $Fonts.Section -Color $Theme.Warning))
        $card4.Controls.Add((New-Label -Text "Passez à l'étape 02 pour préparer la remédiation." `
            -X 20 -Y 42 -Font $Fonts.Small -Color $Theme.TextDim))
    } else {
        $card4.Controls.Add((New-Label -Text 'Système prêt pour la virtualisation imbriquée' `
            -X 20 -Y 15 -Font $Fonts.Section -Color $Theme.Success))
        $card4.Controls.Add((New-Label -Text 'VT-x est libre. ESXi peut démarrer dans Workstation.' `
            -X 20 -Y 42 -Font $Fonts.Small -Color $Theme.TextDim))
    }

    # === Boutons ===
    $btnRefresh = New-SecondaryButton -Text 'Rafraîchir' -X 40 -Y 555
    $btnRefresh.Add_Click({ Show-Step1Diagnostic })
    $mainPanel.Controls.Add($btnRefresh)

    $btnNext = New-PrimaryButton -Text 'Suivant  →' -X 620 -Y 555
    $btnNext.Add_Click({ Show-Step2Selection })
    $mainPanel.Controls.Add($btnNext)

    $btnQuit = New-SecondaryButton -Text 'Quitter' -X 470 -Y 555
    $btnQuit.Add_Click({ $form.Close() })
    $mainPanel.Controls.Add($btnQuit)
}

# ---------------------------------------------------------------------------
#  ÉTAPE 2 : SÉLECTION DES ACTIONS
# ---------------------------------------------------------------------------
function Show-Step2Selection {
    Clear-MainPanel
    Update-Sidebar -Step 2

    Add-PanelHeader -Title 'Préparation des actions' `
                    -Subtitle 'Cochez les remédiations à appliquer — chaque case est expliquée'

    $d = $script:Diagnostic

    # Définition des actions disponibles
    $actions = @(
        @{
            Key = 'HypervisorBoot'
            Title = 'Désactiver l''hyperviseur au démarrage'
            Desc  = 'bcdedit /set hypervisorlaunchtype off — empêche Windows de charger Hyper-V au boot. Indispensable pour libérer VT-x.'
            Recommended = ($d.HypervisorBoot -ne 'Off')
        }
        @{
            Key = 'Registry'
            Title = 'Mettre à zéro les clés Device Guard / VBS'
            Desc  = 'HKLM\System\CurrentControlSet\Control\DeviceGuard — désactive VBS, HVCI et exigences plateforme via le registre.'
            Recommended = ($d.VBSStatusCode -ge 1 -or $d.HVCIRunning)
        }
        @{
            Key = 'CredGuard'
            Title = 'Désactiver Credential Guard'
            Desc  = 'HKLM\System\CurrentControlSet\Control\Lsa\LsaCfgFlags = 0 — désarme la protection LSA isolée.'
            Recommended = ($d.CredGuardRunning -or $d.RegLsaCfg -gt 0)
        }
        @{
            Key = 'Features'
            Title = 'Désinstaller les fonctionnalités Windows de virtualisation'
            Desc  = 'Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform, WSL, Conteneurs, Sandbox — toute la pile DISM.'
            Recommended = ($d.Features.Values -contains $true)
        }
    )

    # Construction des cartes-checkbox
    $y = 140
    $script:CheckBoxes = @{}
    foreach ($a in $actions) {
        $card = New-Card -X 40 -Y $y -Width 720 -Height 90
        $mainPanel.Controls.Add($card)

        $cb = New-Object System.Windows.Forms.CheckBox
        $cb.Location = New-Object System.Drawing.Point(20, 18)
        $cb.Size = New-Object System.Drawing.Size(20, 20)
        $cb.BackColor = $Theme.BgCard
        $cb.Checked = $a.Recommended
        $script:CheckBoxes[$a.Key] = $cb
        $card.Controls.Add($cb)

        $card.Controls.Add((New-Label -Text $a.Title -X 50 -Y 14 `
            -Font $Fonts.Section -Color $Theme.TextMain))

        $descLbl = New-Object System.Windows.Forms.Label
        $descLbl.Text = $a.Desc
        $descLbl.Location = New-Object System.Drawing.Point(50, 42)
        $descLbl.Size = New-Object System.Drawing.Size(620, 40)
        $descLbl.Font = $Fonts.Small
        $descLbl.ForeColor = $Theme.TextDim
        $descLbl.BackColor = [System.Drawing.Color]::Transparent
        $card.Controls.Add($descLbl)

        if ($a.Recommended) {
            $tag = New-Label -Text 'RECOMMANDÉ' -X 600 -Y 16 `
                -Font $Fonts.Small -Color $Theme.Accent
            $card.Controls.Add($tag)
        }

        $y += 100
    }

    # Note d'avertissement
    $warnCard = New-Card -X 40 -Y $y -Width 720 -Height 55
    $warnCard.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#3D2817')
    $mainPanel.Controls.Add($warnCard)
    $warnCard.Controls.Add((New-Label -Text '⚠  Au prochain démarrage, si un écran bleu/violet demande F3, APPUYEZ.' `
        -X 20 -Y 8 -Font $Fonts.BodyBold -Color $Theme.Warning))
    $warnCard.Controls.Add((New-Label -Text 'C''est Windows qui confirme la désactivation. Si vous ratez l''écran, recommencez.' `
        -X 20 -Y 30 -Font $Fonts.Small -Color $Theme.TextMain))

    # Boutons navigation
    $btnBack = New-SecondaryButton -Text '←  Retour' -X 40 -Y 615
    $btnBack.Add_Click({ Show-Step1Diagnostic })
    $mainPanel.Controls.Add($btnBack)

    $btnRun = New-PrimaryButton -Text 'Lancer →' -X 620 -Y 615
    $btnRun.Add_Click({
        foreach ($k in $script:CheckBoxes.Keys) {
            $script:SelectedActions[$k] = $script:CheckBoxes[$k].Checked
        }
        if (($script:SelectedActions.Values | Where-Object { $_ }).Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Aucune action sélectionnée.",
                "Sélection vide", 'OK', 'Information') | Out-Null
            return
        }
        Show-Step3Execution
    })
    $mainPanel.Controls.Add($btnRun)
}

# ---------------------------------------------------------------------------
#  ÉTAPE 3 : EXÉCUTION
# ---------------------------------------------------------------------------
function Show-Step3Execution {
    Clear-MainPanel
    Update-Sidebar -Step 3

    Add-PanelHeader -Title 'Exécution en cours' `
                    -Subtitle 'Application des modifications avec journal en temps réel'

    # Console de log
    $script:LogBox = New-Object System.Windows.Forms.RichTextBox
    $script:LogBox.Location = New-Object System.Drawing.Point(40, 130)
    $script:LogBox.Size = New-Object System.Drawing.Size(720, 430)
    $script:LogBox.BackColor = $Theme.BgDark
    $script:LogBox.ForeColor = $Theme.TextMain
    $script:LogBox.Font = $Fonts.Mono
    $script:LogBox.ReadOnly = $true
    $script:LogBox.BorderStyle = 'None'
    $mainPanel.Controls.Add($script:LogBox)

    $btnContinue = New-PrimaryButton -Text 'Suivant  →' -X 620 -Y 580
    $btnContinue.Enabled = $false
    $btnContinue.Add_Click({ Show-Step4Final })
    $mainPanel.Controls.Add($btnContinue)

    # Lance les actions
    [System.Windows.Forms.Application]::DoEvents()
    Invoke-AllSelectedActions
    $btnContinue.Enabled = $true
    $btnContinue.BackColor = $Theme.Accent
}

# ---------------------------------------------------------------------------
#  ÉTAPE 4 : FINALISATION
# ---------------------------------------------------------------------------
function Show-Step4Final {
    Clear-MainPanel
    Update-Sidebar -Step 4

    Add-PanelHeader -Title 'Finalisation' `
                    -Subtitle 'Vérification post-action et redémarrage'

    # Re-diagnostic pour comparer
    $script:Diagnostic = Get-VBSDiagnostic
    $d = $script:Diagnostic

    # Carte état final
    $card = New-Card -X 40 -Y 130 -Width 720 -Height 200
    $mainPanel.Controls.Add($card)

    $card.Controls.Add((New-Label -Text 'État après application' `
        -X 20 -Y 15 -Font $Fonts.Section -Color $Theme.TextMain))

    $bcdOK = ($d.HypervisorBoot -eq 'Off')
    $card.Controls.Add((New-Label -Text '●' -X 20 -Y 55 -Font $Fonts.Section `
        -Color $(if ($bcdOK) { $Theme.Success } else { $Theme.Warning })))
    $card.Controls.Add((New-Label -Text "BCD hypervisorlaunchtype : $($d.HypervisorBoot)" `
        -X 45 -Y 57 -Font $Fonts.Body -Color $Theme.TextMain))

    $regOK = (($d.RegDeviceGuard['EnableVirtualizationBasedSecurity'] -eq 0) -or
              ($d.RegDeviceGuard.Count -eq 0))
    $card.Controls.Add((New-Label -Text '●' -X 20 -Y 85 -Font $Fonts.Section `
        -Color $(if ($regOK) { $Theme.Success } else { $Theme.Warning })))
    $card.Controls.Add((New-Label -Text 'Registre Device Guard configuré' `
        -X 45 -Y 87 -Font $Fonts.Body -Color $Theme.TextMain))

    $featDisabled = ($d.Features.Values | Where-Object { $_ -eq $true }).Count -eq 0
    $card.Controls.Add((New-Label -Text '●' -X 20 -Y 115 -Font $Fonts.Section `
        -Color $(if ($featDisabled) { $Theme.Success } else { $Theme.Warning })))
    $card.Controls.Add((New-Label -Text 'Fonctionnalités Windows désactivées' `
        -X 45 -Y 117 -Font $Fonts.Body -Color $Theme.TextMain))

    $card.Controls.Add((New-Label -Text 'Note : VBS et l''hyperviseur ne disparaissent qu''APRÈS redémarrage.' `
        -X 20 -Y 155 -Font $Fonts.Small -Color $Theme.TextDim))

    # Carte instructions reboot
    $card2 = New-Card -X 40 -Y 345 -Width 720 -Height 175
    $card2.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#1E2F1E')
    $mainPanel.Controls.Add($card2)

    $card2.Controls.Add((New-Label -Text 'Redémarrage : ce qui va se passer' `
        -X 20 -Y 15 -Font $Fonts.Section -Color $Theme.Success))

    $instructions = @(
        '1.  Windows redémarre normalement.',
        '2.  Un écran bleu ou violet peut apparaître : « Disable Credential Guard / Device Guard ? »',
        '3.  APPUYEZ SUR F3 pour confirmer la désactivation. Sinon Windows recharge VBS.',
        '4.  Windows finit de booter. Relancez msinfo32 pour vérifier que VBS est sur « Non activée ».',
        '5.  Lancez votre VM ESXi dans VMware Workstation : le module HV doit charger.'
    )
    $yi = 50
    foreach ($line in $instructions) {
        $card2.Controls.Add((New-Label -Text $line -X 20 -Y $yi `
            -Font $Fonts.Body -Color $Theme.TextMain -Width 680))
        $yi += 22
    }

    # Boutons
    $btnQuit = New-SecondaryButton -Text 'Quitter sans redémarrer' -X 40 -Y 615 -Width 220
    $btnQuit.Add_Click({ $form.Close() })
    $mainPanel.Controls.Add($btnQuit)

    $btnReboot = New-PrimaryButton -Text 'Redémarrer maintenant' -X 560 -Y 615 -Width 200
    $btnReboot.BackColor = $Theme.Danger
    $btnReboot.Add_MouseEnter({ $this.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#DC2626') })
    $btnReboot.Add_MouseLeave({ $this.BackColor = $Theme.Danger })
    $btnReboot.Add_Click({
        $r = [System.Windows.Forms.MessageBox]::Show(
            "Le PC va redémarrer dans quelques secondes.`r`n`r`nAu boot, GUETTEZ L'ÉCRAN F3 pour confirmer la désactivation.`r`n`r`nContinuer ?",
            "Redémarrage", 'YesNo', 'Warning')
        if ($r -eq 'Yes') {
            Start-Process 'shutdown.exe' -ArgumentList '/r /t 5 /c "Reset VBS - APPUYEZ SUR F3 AU REDEMARRAGE"'
            $form.Close()
        }
    })
    $mainPanel.Controls.Add($btnReboot)
}

# ============================================================================
#  LANCEMENT
# ============================================================================
Show-Step1Diagnostic
[void]$form.ShowDialog()
$form.Dispose()
