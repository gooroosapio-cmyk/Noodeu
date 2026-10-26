"""Extraction et optimisation des 48 cellules générées (aucun dessin de substitution)."""
from PIL import Image
from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[1];dest=root/'public/assets/original/library3d';dest.mkdir(parents=True,exist_ok=True)
atlases=[('exec-e05b2ad8-8b09-44ee-b22f-977662227b6f.png','G01 G02 G03 G04 G05 G07 G08 G09 G10 M01 M04 M07 M09 M11 M12 M16'),('exec-ca3e9541-7e91-4a56-88f0-6bed2a8e3add.png','012 011 021 022 024 025 027 P14 P13 P12 P11 P03 P15 P24 P20 P01'),('exec-fdde0616-96be-4031-83a3-27891fea24ea.png','P22 P23 P21 H01 H02 H03 H04 H05 H06 H07 H08 RND1 RND2 questions tests huisclos')]
records=[]
for name,codes in atlases:
 src=Path('/workspace/generated_images')/name
 im=Image.open(src).convert('RGBA');w,h=im.size
 for i,code in enumerate(codes.split()):
  cell=im.crop((i%4*w//4,i//4*h//4,(i%4+1)*w//4,(i//4+1)*h//4));cell.thumbnail((256,256));p=dest/f'{code}.webp';cell.save(p,'WEBP',quality=88,method=6)
  records.append({'code':code,'file':p.name,'source':name,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'cell':i,'bytes':p.stat().st_size})
(dest/'PROVENANCE.json').write_text(json.dumps({'origin':'Images générées avec imagegen pour Noodeu, 25 octobre 2026. Pas de copie d’actifs WePlay.','rights':'Créations générées pour ce projet ; aucune licence tierce attribuée ni exclusivité juridique revendiquée. Les licences du catalogue de textes restent distinctes.','processing':'Extraction grille4x4 et optimisation WebP alpha256. Originaux conservés dans generated_images.','assets':records},ensure_ascii=False,indent=2)+'\n')
print(len(records),'images',sum(x['bytes'] for x in records),'octets')
