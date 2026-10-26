from pathlib import Path
import json,hashlib
out=Path(__file__).resolve().parents[1]/'public/assets/original/library'
out.mkdir(parents=True,exist_ok=True)
# Dessins vectoriels originaux : chaque composition a un objet sémantique distinct.
shapes={
'G01':'<path d="M27 68 48 26l-2 26h24L46 94l5-26Z" fill="#F4C6AE"/><path d="M76 35h18v43H76z"/><path d="m80 51 5 6 8-13"/>',
'G02':'<rect x="27" y="24" width="65" height="75" rx="9"/><path d="M38 24v75M52 41h27M52 50h18"/><circle cx="67" cy="75" r="13" fill="#F4C6AE"/><path d="m60 75 5 5 10-12"/>',
'G03':'<path d="M21 96V30h32v66M68 96V30h32v66"/><path d="m21 30 23-9v75H21m79-66-23-9v75h23" fill="#F4C6AE"/><circle cx="36" cy="63" r="2"/><circle cx="85" cy="63" r="2"/>',
'G04':'<circle cx="39" cy="42" r="14"/><circle cx="82" cy="42" r="14" fill="#F4C6AE"/><path d="M17 91V78c0-24 44-24 44 0v13M63 91V78c0-24 40-24 40 0v13M52 19h16"/>',
'G05':'<rect x="22" y="38" width="76" height="54" rx="8"/><path d="m24 43 36 29 36-29"/><circle cx="60" cy="34" r="17" fill="#F4C6AE"/><path d="M55 29c0-9 15-9 12 0l-7 6v4M60 44v1"/>',
'G07':'<circle cx="60" cy="61" r="34"/><path d="M50 16h20M60 16v11M60 39v23l15 8"/><circle cx="31" cy="99" r="5" fill="#F4C6AE"/><circle cx="60" cy="103" r="5" fill="#F4C6AE"/><circle cx="89" cy="99" r="5" fill="#F4C6AE"/>',
'G08':'<rect x="17" y="33" width="26" height="58" rx="6"/><rect x="47" y="24" width="26" height="67" rx="6" fill="#F4C6AE"/><rect x="77" y="33" width="26" height="58" rx="6"/><path d="M23 59l5 6 9-13M53 51l14 14m0-14L53 65M84 61l5 5 9-13"/>',
'G09':'<path d="M18 38h84v47H18z"/><path d="M30 52h33M30 66h20M65 66h24"/><path d="m72 26 8-10 11 9-8 10-20 25-12 3 3-12Z" fill="#F4C6AE"/>',
'G10':'<path d="M16 29h56v39H40L25 80V68h-9z"/><path d="M55 54h49v38H91l-13 11V92H55z" fill="#F4C6AE"/><path d="m28 46 8 8 17-18M69 67l19 13m0-13L69 80"/>',
'M01':'<path d="M43 21v79M78 21v79M21 44h79M21 77h79"/><path d="m24 25 12 12m0-12L24 37m26 16 19 17m0-17L50 70"/><circle cx="89" cy="89" r="9" fill="#F4C6AE"/><circle cx="60" cy="31" r="9" fill="#F4C6AE"/>',
'M04':'<path d="M26 26h34v34H26zM60 60h34v34H60z" fill="#F4C6AE"/><path d="M26 94V60M94 26H60M60 60v34"/>'+''.join(f'<circle cx="{x}" cy="{y}" r="4" fill="#48283D"/>' for x in [26,60,94] for y in [26,60,94]),
'M07':'<path d="m20 73 16 22h50l16-22ZM44 70V45h35v25M60 45V20m0 5 25 13H60" fill="#F4C6AE"/><path d="M15 105q12-9 24 0t24 0 24 0 24 0"/>',
'M09':'<path d="M22 99h75M35 99V23h49v16"/><circle cx="84" cy="51" r="12" fill="#F4C6AE"/><path d="M84 63v18m-15-9 15-9 14 9M84 81l-12 13m12-13 12 13"/>',
'M11':'<path d="M24 81 53 44l-7-17c-3-9 7-12 11-4l8 19 14-21c6-8 15-1 9 7L75 51l12 7c14 8 3 38-13 40H43Z" fill="#F4C6AE"/><path d="m29 85 16 8M56 66l17-12"/>',
'M12':'<rect x="27" y="27" width="66" height="66" rx="16" transform="rotate(-12 60 60)" fill="#F4C6AE"/>'+''.join(f'<circle cx="{x}" cy="{y}" r="4" fill="#48283D"/>' for x,y in [(42,42),(78,42),(60,60),(42,78),(78,78)]),
'M16':'<rect x="23" y="26" width="74" height="75" rx="9"/><path d="M40 19v15m40-15v15M23 45h74M48 45v56M73 45v56M23 72h74"/><path d="m30 59 4 5 8-9m13 28 4 5 8-9"/><circle cx="86" cy="19" r="9" fill="#F4C6AE"/>',
'011':'<path d="M60 20C46 42 29 56 29 74a31 31 0 0 0 62 0c0-18-17-32-31-54Z" fill="#F6E3E9"/><path d="m43 73 12 12 24-28"/><path d="M85 24v14m-7-7h14"/>',
'012':'<path d="m60 18 10 26 29-1-23 19 10 28-26-16-26 16 10-28-23-19 29 1Z" fill="#F4C6AE"/><circle cx="60" cy="60" r="10"/>',
'021':'<path d="M29 27h29v28H29zM62 65h29v28H62z"/><path d="M47 48c-27 22 10 50 30 22M72 75c27-22-10-50-30-22"/>',
'022':'<path d="M22 48h76v18H22zM35 66v30m50-30v30"/><path d="M60 47C18 25 48 11 60 27c12-16 42-2 0 20Z" fill="#F4C6AE"/>',
'024':'<path d="M60 97V54M60 69C24 67 22 31 24 30c28-1 39 17 36 39ZM60 53c0-25 20-34 35-32 2 21-10 33-35 32Z" fill="#F6E3E9"/><path d="M42 98h36"/>',
'025':'<path d="M30 28c5 22 15 27 30 33 15-6 25-11 30-33M30 92c5-22 15-27 30-33 15 6 25 11 30 33"/><path d="M37 22h46M37 98h46"/><circle cx="60" cy="61" r="13" fill="#F4C6AE"/>',
'027':'<path d="M14 60q46-57 92 0-46 57-92 0Z"/><circle cx="60" cy="60" r="21" fill="#F4C6AE"/><circle cx="60" cy="60" r="9"/>',
'P01':'<path d="M18 32q22-10 42 0 20-10 42 0v62q-22-10-42 0-20-10-42 0Z"/><path d="M60 32v62M29 46h20m-20 13h20m21-13h20m-20 13h20"/><path d="M53 18h14v20l-7-5-7 5Z" fill="#F4C6AE"/>',
'P03':'<path d="M19 27h82v59H62l-21 18V86H19Z"/><path d="M35 48h50M35 63h33"/><circle cx="89" cy="23" r="12" fill="#F4C6AE"/>',
'P11':'<path d="M25 49h52v29q0 22-26 22T25 78ZM77 53c32-5 31 30 0 25"/><path d="M39 37q-9-9 0-18m17 18q-9-9 0-18"/><path d="M19 103h67"/>',
'P12':'<path d="M23 53h29v26H23zM68 53h29v26H68zM23 79v19m29-19v19m16-19v19m29-19v19M26 53V31h23v22M71 53V31h23v22"/><path d="M54 61h12"/>',
'P13':'<path d="m19 99 25-33 20 13 31-56M76 23h19v22"/><path d="M25 99h74"/><circle cx="43" cy="66" r="7" fill="#F4C6AE"/>',
'P14':'<path d="m60 18 32 21v43L60 103 28 82V39Z"/><path d="m60 32 9 21 22 7-22 8-9 22-9-22-22-8 22-7Z" fill="#F4C6AE"/>',
'P15':'<path d="M23 69c0-47 74-47 74 0M23 69l-9-16m9 16 16-9M97 69l9-16m-9 16-16-9"/><path d="M60 91C19 68 47 53 60 69c13-16 41-1 0 22Z" fill="#F4C6AE"/>',
'P20':'<path d="M21 98V78h17V61h19V44h20V26h23v72Z" fill="#F6E3E9"/><path d="M19 102h84"/>'+''.join(f'<circle cx="{x}" cy="{y}" r="3" fill="#48283D"/>' for x,y in [(29,68),(47,51),(67,34),(88,16),(109,91)]),
'P21':'<circle cx="60" cy="60" r="39"/><path d="m77 37-11 29-23 17 11-29Z" fill="#F4C6AE"/><circle cx="60" cy="60" r="4"/>',
'P22':'<rect x="23" y="30" width="74" height="65" rx="8"/><path d="M23 48h74M40 22v17m40-17v17"/><path d="M79 73H43l12-12m-12 12 12 12"/>',
'P23':'<path d="M60 17 94 32v28c0 21-17 33-34 43-17-10-34-22-34-43V32Z" fill="#F6E3E9"/><path d="M60 78C23 57 48 39 60 55c12-16 37 2 0 23Z" fill="#F4C6AE"/>',
'P24':'<path d="m17 52 43-33 43 33M29 44v54h62V44"/><path d="M60 86C26 67 49 53 60 67c11-14 34 0 0 19Z" fill="#F4C6AE"/>',
'H01':'<path d="M36 99V48q0-10 9-5V29q0-12 10-7v21-25q0-12 10 0v25-20q0-12 10 0v27-13q0-11 10 0v36q0 27-25 27Z" fill="#F4C6AE"/>',
'H02':'<path d="M17 30h58v35H45L31 78V65H17zM61 60h43v34H91l-13 10V94H61Z"/><path d="M36 43c-9-9-17 7 10 15 27-8 19-24 10-15l-10 5Z" fill="#F4C6AE"/>',
'H03':'<circle cx="60" cy="25" r="12"/><path d="M48 44h24l20 26-10 8-14-18v42H52V60L38 78 28 70Z" fill="#F6E3E9"/><path d="M60 76v26"/>',
'H04':'<path d="M60 19 93 32v29c0 21-21 35-33 41-12-6-33-20-33-41V32Z"/><path d="M49 44h22v12h12v21H71v12H49V77H37V56h12Z" fill="#F4C6AE"/>',
'H05':'<path d="M44 83c0-14-16-19-16-38 0-39 64-39 64 0 0 19-16 24-16 38ZM44 91h32M49 101h22"/><path d="M54 38c0-11 19-11 17 0l-11 12v6m0 9v1"/>',
'H06':'<path d="M24 30h72v64H24zM35 42h31m-31 15h20m-20 15h22"/><path d="M78 49v51m-12-15 12 15 12-15"/><circle cx="87" cy="28" r="12" fill="#F4C6AE"/>',
'H07':'<path d="M25 49v-9a35 35 0 0 1 70 0v9M19 47h18v32H19zM83 47h18v32H83zM92 79c0 20-18 23-32 23"/><rect x="47" y="95" width="20" height="12" rx="6" fill="#F4C6AE"/>',
'H08':'<path d="m17 28 38 8v40c-19 20-38 0-38-14ZM65 36l38-8v34c0 14-19 34-38 14Z"/><path d="M26 49h15m33 0h15M26 65q8 12 16 0m32 9q8-12 16 0"/>',
'RND1':'<path d="M20 36h19c20 0 22 48 42 48h20M20 84h19c20 0 22-48 42-48h20m-12-12 12 12-12 12m0 24 12 12-12 12"/>',
'RND2':'<rect x="35" y="49" width="51" height="48" rx="9" fill="#F4C6AE"/><path d="M45 49V34c0-23 31-23 31 0v15M16 42l9-10 9 10m61 34 10 10 9-10"/><circle cx="60" cy="68" r="5"/><path d="M60 73v10"/>',
'questions':'<circle cx="43" cy="59" r="29"/><circle cx="80" cy="59" r="29" fill="#F4C6AE"/><path d="M36 48h14m-7-7v14M72 52c0-12 19-12 17 0l-9 9v5m0 9v1"/>',
 'tests':'<rect x="27" y="24" width="66" height="78" rx="9"/><path d="M46 17h28v16H46zM39 49l5 5 9-12m8 9h19M39 72l5 5 9-12m8 9h19"/>',
 'huisclos':'<path d="M29 97V48a31 31 0 0 1 62 0v49Z" fill="#F4C6AE"/><path d="M41 97V49a19 19 0 0 1 38 0v48M54 63h13v19H54z"/>'}
shapes['G06']='<path d="M25 25h70v70H25z"/><circle cx="60" cy="48" r="13"/><path d="M39 81c0-23 42-23 42 0M17 105h18m8 0h18m8 0h18"/>'
for name,body in shapes.items():
 svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120"><g stroke="#48283D" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" fill="#FFF9F0">'+body+'</g></svg>'
 (out/(name+'.svg')).write_text(svg)
(out/'manifest.json').write_text(json.dumps({'provenance':'Dessins SVG originaux créés pour Noodeu, 2026-10-25 ; pas d’actif tiers incorporé.','palette':['#48283D','#F4C6AE','#FFF9F0','#F6E3E9'],'files':[{'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(out.glob('*.svg'))]},ensure_ascii=False,indent=2))
print(len(shapes),'illustrations')
