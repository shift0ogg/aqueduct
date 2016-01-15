import 'package:test/test.dart';
import 'package:monadart/monadart.dart';
import 'package:postgresql/postgresql.dart' as postgresql;

void main() {
  PostgresModelAdapter adapter;

  setUp(() {
    adapter = new PostgresModelAdapter(null, () async {
      var uri = 'postgres://dart:dart@localhost:5432/dart_test';
      return await postgresql.connect(uri);
    });
  });

  tearDown(() {
    adapter.close();
    adapter = null;
  });

  test("Updating existing object works", () async {
    await generateTemporarySchemaFromModels(adapter, [TestModel]);

    var m = new TestModel()
      ..name = "Bob"
      ..emailAddress = "1@a.com";

    var req = new Query<TestModel>()..valueObject = m;
    await req.insert(adapter);

    m
      ..name = "Fred"
      ..emailAddress = "2@a.com";

    req = new Query<TestModel>()
      ..predicate = new Predicate("name = @name", {"name": "Bob"})
      ..valueObject = m;

    var response = await req.update(adapter);
    var result = response.first;

    expect(result.name, "Fred");
    expect(result.emailAddress, "2@a.com");
  });

  test("Setting relationship to null succeeds", () async {
    await generateTemporarySchemaFromModels(adapter, [Child, Parent]);

    var parent = new Parent()
      ..name = "Bob";
    var q = new Query<Parent>()
      ..valueObject = parent;
    parent = await q.insert(adapter);

    var child = new Child()
      ..name = "Fred"
      ..parent = parent;
    q = new Query<Child>()
      ..valueObject = child;
    child = await q.insert(adapter);
    expect(child.parent.id, parent.id);

    q = new Query<Child>()
      ..predicateObject = (new Child()..id = child.id)
      ..valueObject = (new Child()..parent = null);
    child = (await q.update(adapter)).first;
    expect(child.parent, isNull);
  });

  test("Updating non-existant object fails", () async {});
}

@ModelBacking(TestModelBacking)
@proxy
class TestModel extends Object with Model implements TestModelBacking {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class TestModelBacking extends Model {
  @Attributes(primaryKey: true, databaseType: "bigserial")
  int id;

  String name;

  @Attributes(nullable: true, unique: true)
  String emailAddress;
}

@ModelBacking(ChildBacking) @proxy
class Child extends Object with Model implements ChildBacking {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class ChildBacking {
  @Attributes(primaryKey: true, databaseType: "bigserial")
  int id;

  String name;

  @Attributes(nullable: true)
  @RelationshipAttribute(RelationshipType.belongsTo, "child")
  Parent parent;
}

@ModelBacking(ParentBacking) @proxy
class Parent extends Object with Model implements ChildBacking {
  noSuchMethod(i) => super.noSuchMethod(i);
}

class ParentBacking {
  @Attributes(primaryKey: true, databaseType: "bigserial")
  int id;

  String name;

  @RelationshipAttribute(RelationshipType.hasOne, "parent")
  Child child;
}
