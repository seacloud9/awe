package awe;

#if macro
import haxe.macro.Context;
import haxe.macro.Type;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
import haxe.macro.Expr;
#end
import awe.util.MacroTools;

class Archetype {
	var types: Array<ComponentType>;
	var cid: Int;
	public function new(cid: Int, types: Array<ComponentType>) {
		this.cid = cid;
		this.types = types;
	}
	public function create(engine: Engine): Entity {
		return cast 0;
	}
	public static macro function build(types: Array<ExprOf<Class<Component>>>): ExprOf<Archetype> {
		var newTypes = [];
		var cid = 0;
		for(ty in types) {
			var ty = MacroTools.resolveTypeLiteral(ty);
			var cty = awe.ComponentType.get(ty);
			cid |= cty.getPure();
			newTypes.push(cty);
		}
		return macro new Archetype($v{cid}, $v{newTypes});
	}
}