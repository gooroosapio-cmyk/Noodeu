import type { ButtonHTMLAttributes, CSSProperties, ReactNode } from "react";
import "./noodeu.css";
export type NoodeuIconName = "home" | "library" | "bulb" | "heart" | "settings" | "arrow-left" | "arrow-right" | "chevron-down" | "chevron-up" | "close" | "check" | "plus" | "minus" | "search" | "filter" | "bookmark" | "star" | "share" | "send" | "copy" | "link" | "users" | "user" | "chat" | "pause" | "play" | "stop" | "skip" | "mic" | "image" | "volume" | "clock" | "lock" | "eye" | "eye-off" | "bell" | "wifi" | "refresh" | "logout" | "info" | "help" | "pencil" | "undo" | "eraser" | "smile" | "puzzle" | "cards" | "lightning" | "leaf" | "sparkles" | "delete" | "quote";
const BASE = "/assets/noodeu";
export function NoodeuIcon({name,size=24,label}:{name:NoodeuIconName;size?:number;label?:string}) {
 const style={width:size,height:size,"--nd-icon-url":`url("${BASE}/03_Icones_SVG/icon-${name}.svg")`} as CSSProperties;
 return <span className="nd-icon" style={style} role={label?"img":undefined} aria-label={label} aria-hidden={label?undefined:true}/>;
}
export function NoodeuLogo(){return <img className="nd-logo" src={`${BASE}/01_Logos/noodeu-logo-couleur.svg`} width="830" height="190" alt="Noodeu"/>}
export function NoodeuIllustration({file,alt="",width=280,height=210}:{file:string;alt?:string;width?:number;height?:number}) {
 return <img className="nd-illustration" src={`${BASE}/02_Illustrations_PNG/${file}`} alt={alt} width={width} height={height} loading="lazy" decoding="async"/>;
}
export function NoodeuButton({children,icon,variant="primary",className="",...props}:ButtonHTMLAttributes<HTMLButtonElement>&{children:ReactNode;icon?:NoodeuIconName;variant?:"primary"|"secondary"}) {
 return <button {...props} type={props.type??"button"} className={`nd-button nd-button--${variant} ${className}`}>{icon&&<NoodeuIcon name={icon}/>}<span>{children}</span></button>;
}
export function NoodeuLoading({label="Chargement…"}:{label?:string}){return <span role="status"><span className="nd-loading" aria-hidden="true"><i/><i/><i/></span> <span>{label}</span></span>}
export function NoodeuEmptyState({file,title,description,action}:{file:string;title:string;description:string;action:ReactNode}){return <section className="nd-empty"><NoodeuIllustration file={file}/><h2>{title}</h2><p>{description}</p>{action}</section>}
export const noodeuNavigation: {path:string;label:string;icon:NoodeuIconName}[]=[
 {path:"/accueil",label:"Accueil",icon:"home"},
 {path:"/bibliotheques",label:"Bibliothèques",icon:"library"},
 {path:"/astuces",label:"Astuces",icon:"bulb"},
 {path:"/notre-espace",label:"Notre espace",icon:"heart"},
 {path:"/parametres",label:"Paramètres",icon:"settings"},
];
// Adapter les liens au routeur du projet; masquer la navigation pendant une partie.
export function NoodeuBottomNav({currentPath}:{currentPath:string}){return <nav className="nd-nav" aria-label="Navigation principale">{noodeuNavigation.map(item=><a key={item.path} href={item.path} aria-current={currentPath===item.path?"page":undefined}><NoodeuIcon name={item.icon}/><span>{item.label}</span></a>)}</nav>}
